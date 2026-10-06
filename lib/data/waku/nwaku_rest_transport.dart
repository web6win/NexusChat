import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart' show immutable;
import 'package:http/http.dart' as http;

import 'waku_message.dart';
import 'waku_transport.dart';

/// 透过 nwaku（或任何相容的 Waku v2 REST 节点）收发讯息。
///
/// 支援两种网路模式，会自动侦测：
///
/// 1. 自动分片（auto-sharding，公共 Waku 网路 / cluster 1）：
///    - 发布：`POST /relay/v1/auto/messages`
///    - 订阅：`POST /relay/v1/auto/subscriptions`（content topic 阵列）
///    - 拉取：`GET /relay/v1/auto/messages/{contentTopic}`
///
/// 2. 静态分片（static-sharding，私有 cluster，例如 cluster-id=10000）：
///    - 发布：`POST /relay/v1/messages/{pubsubTopic}`
///    - 订阅：`POST /relay/v1/subscriptions`（pubsub topic 阵列）
///    - 拉取：`GET /relay/v1/messages/{pubsubTopic}`，再在本地依 contentTopic 筛选
///
/// 当 `POST /relay/v1/auto/subscriptions` 回传「Static sharding is used」
/// 时，会自动切到模式 2。nexuschat 预设使用 cluster 10000 shard 0，
/// 因此 pubsub topic 固定为 `/waku/2/rs/10000/0`。
///
/// 即时来源仍保留 filter v2：`POST /filter/v2/subscriptions` + `GET
/// /filter/v2/messages/{contentTopic}`，由节点主动把订阅的讯息收进快取，
/// 客户端只要快速取走即可，延迟不再受限于轮询周期。
///
/// 为什么要合并多个来源：filter / relay 快取都只保留节点最近收到的讯息，
/// 且被读走即清空；同一节点上有多个客户端轮询时，讯息可能被先轮询的一方
/// 拉走。store 则保存节点转发过的所有讯息（依 retention policy），多边合并
/// 去重才能保证金钥包与聊天讯息不漏接。
class NwakuRestTransport extends WakuTransport {
  NwakuRestTransport({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  /// 节点位址，例如 `https://waku01.web6.win/`。
  final String baseUrl;

  final http.Client _client;

  @override
  bool isRunning = false;

  @override
  TransportKind get kind => TransportKind.nwakuRest;

  /// 已成功订阅的 content topic（filter 推播用）。
  final Set<String> _subscribed = <String>{};

  DateTime? _lastSubscribeAt;

  /// 节点是否支援 filter v2；不支援就退回纯轮询，不再尝试订阅。
  bool _filterAvailable = true;

  /// filter v2 订阅是否真的建立成功。
  ///
  /// [_filterAvailable] 只代表「端点存在」，不代表订阅成立：节点若没有可用的
  /// filter service peer（例如 Relay 尚未连上任何 peer），订阅会回 503，此时
  /// 去读 `GET /filter/v2/messages/{topic}` 只会拿到 400 `Not subscribed to
  /// topic`。因此读 filter 快取前必须先确认订阅真的成功过。
  bool _filterSubscribed = false;

  /// 节点是否支援 relay auto-sharding 订阅；不支援就不再尝试。
  bool _relayAutoAvailable = true;

  /// 节点使用静态分片（static sharding）。一旦侦测到就切换为静态 endpoint。
  bool _staticMode = false;

  /// 是否已向静态 pubsub topic 订阅。
  bool _staticSubscribed = false;

  /// 节点是否不支援 `/relay/v1/subscriptions`（回传 404/400）。
  /// 确认后才会 fallback 到 auto-sharding endpoint。
  bool _staticEndpointUnavailable = false;

  /// 静态分片模式下使用的 pubsub topic（cluster 10000 shard 0）。
  static const _staticPubsubTopic = '/waku/2/rs/10000/0';

  /// 用来节流「较重」的 store / relay 查询。
  int _queryCount = 0;

  /// filter 订阅的 TTL 是 5 分钟，这里提前重发以免断订。
  static const _refreshInterval = Duration(minutes: 3);

  /// 同一节点上可能有多个客户端，固定 id 让订阅可重复刷新（SUBSCRIBE 是累加）。
  static const _subscriptionId = 'nexuschat';

  /// filter v2 连续失败次数；达到阈值后关闭 filter，避免在 CORS 未配好的节点上无限重试。
  int _filterFailureCount = 0;
  static const _filterFailureThreshold = 3;

  static const _jsonContentType = 'application/json';

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$base$path').replace(
      queryParameters: query?.map(
        (k, v) => MapEntry(k, v is List ? v.map((e) => '$e').toList() : '$v'),
      ),
    );
  }

  @override
  Future<void> start() async {
    isRunning = true;
  }

  @override
  Future<void> stop() async {
    isRunning = false;
    _subscribed.clear();
    _lastSubscribeAt = null;
    _filterSubscribed = false;
  }

  /// 订阅：尝试 filter v2 推播，并主动侦测节点是否使用静态分片。
  ///
  /// 对 cluster 10000 这类静态分片节点，直接对 `/relay/v1/subscriptions`
  /// 订阅 pubsub topic，不必依赖 auto-sharding 的 500 侦测；
  /// 若该端点回 404/400，代表节点走 auto-sharding，再 fallback 到
  /// `/relay/v1/auto/subscriptions`。
  ///
  /// 只有「有新 topic」或「订阅快过期」时才真的发请求；失败不抛错，
  /// 上层仍会用一般轮询收到讯息。
  @override
  Future<void> subscribe(List<String> contentTopics) async {
    if (contentTopics.isEmpty) return;
    final hasNew = contentTopics.any((t) => !_subscribed.contains(t));
    final last = _lastSubscribeAt;
    final expired =
        last == null || DateTime.now().difference(last) > _refreshInterval;
    if (!hasNew && !expired) return;

    var anySuccess = false;

    // 1) filter v2 推播订阅。
    if (_filterAvailable) {
      try {
        final response = await _client
            .post(
              _uri('/filter/v2/subscriptions'),
              headers: const <String, String>{
                'content-type': _jsonContentType,
              },
              body: jsonEncode(<String, dynamic>{
                'requestId': _subscriptionId,
                'contentFilters': contentTopics,
              }),
            )
            .timeout(const Duration(seconds: 8));
        if (response.statusCode == 404 || response.statusCode == 400) {
          // 节点版本不相容或未启用 filter：关掉这条路，退回纯轮询。
          _filterAvailable = false;
          _filterSubscribed = false;
        } else if (response.statusCode < 300) {
          _filterSubscribed = true;
          anySuccess = true;
          _filterFailureCount = 0;
        } else {
          // 5xx（例如 503「No suitable service peer」）：节点本身没有可用的
          // filter peer，订阅并未成立。累计失败次数后直接关闭这条路，否则
          // 每一轮都会去打 filter 快取并换回一堆 400。
          _filterSubscribed = false;
          _filterFailureCount++;
          if (_filterFailureCount >= _filterFailureThreshold) {
            _filterAvailable = false;
          }
        }
      } catch (_) {
        // CORS 或网路问题会导致订阅被挡掉；连续几次失败后关闭 filter，
        // 让讯息改由 relay / store 兜底，避免 devtools 充满红字。
        _filterFailureCount++;
        if (_filterFailureCount >= _filterFailureThreshold) {
          _filterAvailable = false;
        }
      }
    }

    // 2) 优先尝试静态分片订阅：对 waku01 (cluster 10000) 这类静态分片节点，
    //    直接对 /relay/v1/subscriptions 订阅 pubsub topic 即可；CORS preflight
    //    已由反向代理正确回应 OPTIONS，因此使用标准的 application/json。
    if (!_staticSubscribed && !_staticEndpointUnavailable) {
      try {
        final response = await _client
            .post(
              _uri('/relay/v1/subscriptions'),
              headers: const <String, String>{
                'content-type': _jsonContentType,
              },
              body: jsonEncode(<String>[_staticPubsubTopic]),
            )
            .timeout(const Duration(seconds: 8));
        if (response.statusCode == 404 || response.statusCode == 400) {
          // 节点不支援静态分片 endpoint，走 auto-sharding fallback。
          _staticEndpointUnavailable = true;
        } else if (response.statusCode < 300) {
          _staticMode = true;
          _staticSubscribed = true;
          anySuccess = true;
        }
      } catch (_) {
        // 网路/CORS 问题：保持 false，下次重试。
      }
    }

    // 3) 静态分片走不通才走 auto-sharding。
    if (_relayAutoAvailable && !_staticMode && !_staticSubscribed) {
      try {
        final response = await _client
            .post(
              _uri('/relay/v1/auto/subscriptions'),
              headers: const <String, String>{
                'content-type': _jsonContentType,
              },
              body: jsonEncode(contentTopics),
            )
            .timeout(const Duration(seconds: 8));
        if (response.statusCode == 404 || response.statusCode == 400) {
          // 节点版本不相容或未启用 auto-sharding relay。
          _relayAutoAvailable = false;
        } else if (response.statusCode >= 500 &&
            response.body.contains('Static sharding is used')) {
          // 节点使用静态分片，auto endpoint 不接受纯 content topic。
          _staticMode = true;
        } else if (response.statusCode < 300) {
          anySuccess = true;
        }
      } catch (_) {
        // 订阅失败不影响主流程，下一轮会再试
      }
    }

    if (anySuccess) {
      _subscribed.addAll(contentTopics);
      _lastSubscribeAt = DateTime.now();
    }
  }

  @override
  Future<void> publish(WakuMessage message) async {
    final path = _staticMode
        ? '/relay/v1/messages/${Uri.encodeComponent(_staticPubsubTopic)}'
        : '/relay/v1/auto/messages';
    final response = await _client
        .post(
          _uri(path),
          headers: const <String, String>{
            'content-type': _jsonContentType,
          },
          body: jsonEncode(message.toJson()),
        )
        // 图片讯息的 payload 可达数百 KB，慢速网路下 10 秒太紧；
        // 放宽到 20 秒，避免「其实送得出去、却被逾时判死」。
        .timeout(const Duration(seconds: 20));
    if (response.statusCode >= 300) {
      throw WakuTransportException(
        'publish failed (${response.statusCode}): ${response.body}',
      );
    }
  }

  @override
  Future<List<WakuMessage>> query({
    required List<String> contentTopics,
    int? sinceMs,
    int limit = 100,
  }) {
    // 三个来源都查，合并去重；全部失败才向上抛错。
    final merged = <WakuMessage>[];
    final seen = <String>{};
    Object? firstError;

    void merge(List<WakuMessage> incoming) {
      for (final message in incoming) {
        final key =
            '${message.contentTopic}|${message.timestampNs}|${message.payloadBase64}';
        if (seen.add(key)) merged.add(message);
      }
    }

    Future<void> safe(Future<List<WakuMessage>> Function() source) async {
      try {
        merge(await source());
      } catch (error) {
        firstError ??= error;
      }
    }

    return () async {
      // 1) 即时来源：filter 推播快取。节点已经帮我们把订阅的讯息收好，
      //    每轮都取，延迟就只取决于轮询间隔。必须确认订阅成立过才读，
      //    否则未订阅的 topic 会一直回 400。
      if (_filterAvailable && _filterSubscribed) {
        await safe(() => _queryFilterCache(contentTopics));
      }

      // 2) 兜底来源：store（历史）+ relay 快取。两者都比 filter 重
      //    （relay 要逐 topic 打一次），所以节流：full 查询一定做，
      //    其余每 5 轮做一次，避免漏掉离线期间或没被推播到的讯息。
      _queryCount++;
      if (sinceMs == null || _queryCount % 5 == 0) {
        await safe(() => _queryStore(contentTopics, sinceMs, limit));
        await safe(() => _queryRelayCache(contentTopics));
      }

      final error = firstError;
      if (merged.isEmpty && error != null) {
        throw error;
      }
      merged.sort((a, b) => a.timestampNs.compareTo(b.timestampNs));
      return merged;
    }();
  }

  /// filter 推播快取：`GET /filter/v2/messages/{contentTopic}`。
  ///
  /// 呼叫前必须确认 filter 订阅已成立（`_filterSubscribed`）；未订阅的 topic
  /// 节点会回 400 `Not subscribed to topic`，那种请求纯属噪音，应在源头挡掉。
  /// 过程中的其他失败（逾时、连线中断）一律视为空，上层还有 store 兜底。
  Future<List<WakuMessage>> _queryFilterCache(
    List<String> contentTopics,
  ) async {
    final out = <WakuMessage>[];
    for (final topic in contentTopics) {
      if (!_subscribed.contains(topic)) continue;
      final http.Response response;
      try {
        response = await _client
            .get(_uri('/filter/v2/messages/${Uri.encodeComponent(topic)}'))
            .timeout(const Duration(seconds: 6));
      } on TimeoutException {
        continue;
      } on http.ClientException {
        continue;
      }
      if (response.statusCode >= 300) continue;
      out.addAll(_decodeList(response.body));
    }
    return out;
  }

  /// relay 快取。
  ///
  /// - 自动分片模式：逐 content topic 呼叫 `GET /relay/v1/auto/messages/{topic}`；
  ///   404 代表该 topic 暂无快取（或节点未订阅），视为空而非错误。
  /// - 静态分片模式：一次呼叫 `GET /relay/v1/messages/{pubsubTopic}` 取回该
  ///   shard 的所有讯息，再用 content topic 在本地筛选。
  Future<List<WakuMessage>> _queryRelayCache(
    List<String> contentTopics,
  ) async {
    if (_staticMode) {
      if (!_staticSubscribed) return const <WakuMessage>[];
      final http.Response response;
      try {
        response = await _client
            .get(
              _uri('/relay/v1/messages/${Uri.encodeComponent(_staticPubsubTopic)}'),
            )
            .timeout(const Duration(seconds: 10));
      } on TimeoutException {
        return const <WakuMessage>[];
      } on http.ClientException {
        return const <WakuMessage>[];
      }
      if (response.statusCode == 404) return const <WakuMessage>[];
      if (response.statusCode >= 300) {
        throw WakuTransportException('relay query ${response.statusCode}');
      }
      final all = _decodeList(response.body);
      return all.where((m) => contentTopics.contains(m.contentTopic)).toList();
    }

    if (!_relayAutoAvailable) return const <WakuMessage>[];
    final out = <WakuMessage>[];
    for (final topic in contentTopics) {
      final http.Response response;
      try {
        response = await _client
            .get(_uri('/relay/v1/auto/messages/${Uri.encodeComponent(topic)}'))
            .timeout(const Duration(seconds: 10));
      } on TimeoutException {
        continue;
      } on http.ClientException {
        continue;
      }
      if (response.statusCode == 404) continue;
      if (response.statusCode >= 300) {
        throw WakuTransportException('relay query ${response.statusCode}');
      }
      out.addAll(_decodeList(response.body));
    }
    return out;
  }

  /// store v3：`GET /store/v3/messages?includeData=true&contentTopics=...`。
  Future<List<WakuMessage>> _queryStore(
    List<String> contentTopics,
    int? sinceMs,
    int limit,
  ) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    // 没有 since 时预设回看 48 小时（nwaku 预设 retention 也是 2 天）
    final startMs =
        sinceMs != null && sinceMs > 0 ? sinceMs : nowMs - 48 * 3600 * 1000;
    final response = await _client
        .get(
          _uri('/store/v3/messages', <String, dynamic>{
            'includeData': 'true',
            // 一定要「由新到旧」：没有 since 的查询（例如捞金钥包）预设回看
            // 48 小时，而金钥包每 2 分钟重发一次，若取最旧的 N 则永远只看得到
            // 最早那批，新加入的联络人会卡在「同步中」。
            'ascending': 'false',
            'pageSize': '$limit',
            'timeStart': '${startMs * 1000000}',
            'timeEnd': '${nowMs * 1000000}',
            'contentTopics': contentTopics,
          }),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode >= 300) {
      throw WakuTransportException('store query ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is List) return _decodeList(response.body);
    if (decoded is Map && decoded['messages'] is List) {
      return (decoded['messages'] as List)
          .whereType<Map>()
          // store v3 每笔是 {"messageHash":..,"message":{..},"pubsubTopic":..}
          // 真正的栏位在 "message" 里面，必须拆开否则会解析出一堆空讯息。
          .map((raw) {
            final inner = raw['message'];
            final source = inner is Map ? inner : raw;
            return WakuMessage.fromJson(Map<String, dynamic>.from(source));
          })
          .where((m) => m.contentTopic.isNotEmpty && m.payloadBase64.isNotEmpty)
          .toList();
    }
    return const <WakuMessage>[];
  }

  List<WakuMessage> _decodeList(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! List) return const <WakuMessage>[];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(WakuMessage.fromJson)
        .toList();
  }

  @override
  Future<TransportHealth> health() async {
    final stopwatch = Stopwatch()..start();
    try {
      var response = await _client
          .get(_uri('/health'))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode >= 300) {
        response = await _client
            .get(_uri('/debug/v1/info'))
            .timeout(const Duration(seconds: 6));
      }
      stopwatch.stop();
      final ok = response.statusCode < 300;
      return TransportHealth(
        ok: ok,
        latencyMs: stopwatch.elapsedMilliseconds,
        relayReady: ok && _relayReady(response.body),
        detail: ok ? response.body.trim().isEmpty ? null : response.body.trim() : null,
      );
    } catch (error) {
      stopwatch.stop();
      return TransportHealth(ok: false, detail: '$error');
    }
  }

  /// 由 `/health` 的内容判断节点的 relay 是否已入网。
  ///
  /// 只认得 `connectionStatus`；解析失败（例如 fallback 到 `/debug/v1/info`）
  /// 时回传 true，避免因为看不懂回应就误报「无 peer」。
  static bool _relayReady(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return true;
      final status = decoded['connectionStatus'];
      if (status is! String || status.isEmpty) return true;
      return status.toLowerCase() == 'connected';
    } catch (_) {
      return true;
    }
  }

  @override
  void dispose() {
    _client.close();
  }
}

/// 传输层例外。
@immutable
class WakuTransportException implements Exception {
  const WakuTransportException(this.message);

  final String message;

  @override
  String toString() => 'WakuTransportException: $message';
}

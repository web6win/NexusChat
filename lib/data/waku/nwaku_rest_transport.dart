import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart' show immutable;
import 'package:http/http.dart' as http;

import 'waku_message.dart';
import 'waku_transport.dart';

/// 透過 nwaku（或任何相容的 Waku v2 REST 節點）收發訊息。
///
/// 支援兩種網路模式，會自動偵測：
///
/// 1. 自動分片（auto-sharding，公共 Waku 網路 / cluster 1）：
///    - 發布：`POST /relay/v1/auto/messages`
///    - 訂閱：`POST /relay/v1/auto/subscriptions`（content topic 陣列）
///    - 拉取：`GET /relay/v1/auto/messages/{contentTopic}`
///
/// 2. 靜態分片（static-sharding，私有 cluster，例如 cluster-id=10000）：
///    - 發布：`POST /relay/v1/messages/{pubsubTopic}`
///    - 訂閱：`POST /relay/v1/subscriptions`（pubsub topic 陣列）
///    - 拉取：`GET /relay/v1/messages/{pubsubTopic}`，再在本地依 contentTopic 篩選
///
/// 當 `POST /relay/v1/auto/subscriptions` 回傳「Static sharding is used」
/// 時，會自動切到模式 2。nexuschat 預設使用 cluster 10000 shard 0，
/// 因此 pubsub topic 固定為 `/waku/2/rs/10000/0`。
///
/// 即時來源仍保留 filter v2：`POST /filter/v2/subscriptions` + `GET
/// /filter/v2/messages/{contentTopic}`，由節點主動把訂閱的訊息收進快取，
/// 客戶端只要快速取走即可，延遲不再受限於輪詢週期。
///
/// 為什麼要合併多個來源：filter / relay 快取都只保留節點最近收到的訊息，
/// 且被讀走即清空；同一節點上有多個客戶端輪詢時，訊息可能被先輪詢的一方
/// 拉走。store 則保存節點轉發過的所有訊息（依 retention policy），多邊合併
/// 去重才能保證金鑰包與聊天訊息不漏接。
class NwakuRestTransport extends WakuTransport {
  NwakuRestTransport({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  /// 節點位址，例如 `https://waku01.web6.win/`。
  final String baseUrl;

  final http.Client _client;

  @override
  bool isRunning = false;

  @override
  TransportKind get kind => TransportKind.nwakuRest;

  /// 已成功訂閱的 content topic（filter 推播用）。
  final Set<String> _subscribed = <String>{};

  DateTime? _lastSubscribeAt;

  /// 節點是否支援 filter v2；不支援就退回純輪詢，不再嘗試訂閱。
  bool _filterAvailable = true;

  /// filter v2 訂閱是否真的建立成功。
  ///
  /// [_filterAvailable] 只代表「端點存在」，不代表訂閱成立：節點若沒有可用的
  /// filter service peer（例如 Relay 尚未連上任何 peer），訂閱會回 503，此時
  /// 去讀 `GET /filter/v2/messages/{topic}` 只會拿到 400 `Not subscribed to
  /// topic`。因此讀 filter 快取前必須先確認訂閱真的成功過。
  bool _filterSubscribed = false;

  /// 節點是否支援 relay auto-sharding 訂閱；不支援就不再嘗試。
  bool _relayAutoAvailable = true;

  /// 節點使用靜態分片（static sharding）。一旦偵測到就切換為靜態 endpoint。
  bool _staticMode = false;

  /// 是否已向靜態 pubsub topic 訂閱。
  bool _staticSubscribed = false;

  /// 節點是否不支援 `/relay/v1/subscriptions`（回傳 404/400）。
  /// 確認後才會 fallback 到 auto-sharding endpoint。
  bool _staticEndpointUnavailable = false;

  /// 靜態分片模式下使用的 pubsub topic（cluster 10000 shard 0）。
  static const _staticPubsubTopic = '/waku/2/rs/10000/0';

  /// 用來節流「較重」的 store / relay 查詢。
  int _queryCount = 0;

  /// filter 訂閱的 TTL 是 5 分鐘，這裡提前重發以免斷訂。
  static const _refreshInterval = Duration(minutes: 3);

  /// 同一節點上可能有多個客戶端，固定 id 讓訂閱可重複刷新（SUBSCRIBE 是累加）。
  static const _subscriptionId = 'nexuschat';

  /// filter v2 連續失敗次數；達到閾值後關閉 filter，避免在 CORS 未配好的節點上無限重試。
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

  /// 訂閱：嘗試 filter v2 推播，並主動偵測節點是否使用靜態分片。
  ///
  /// 對 cluster 10000 這類靜態分片節點，直接對 `/relay/v1/subscriptions`
  /// 訂閱 pubsub topic，不必依賴 auto-sharding 的 500 偵測；
  /// 若該端點回 404/400，代表節點走 auto-sharding，再 fallback 到
  /// `/relay/v1/auto/subscriptions`。
  ///
  /// 只有「有新 topic」或「訂閱快過期」時才真的發請求；失敗不拋錯，
  /// 上層仍會用一般輪詢收到訊息。
  @override
  Future<void> subscribe(List<String> contentTopics) async {
    if (contentTopics.isEmpty) return;
    final hasNew = contentTopics.any((t) => !_subscribed.contains(t));
    final last = _lastSubscribeAt;
    final expired =
        last == null || DateTime.now().difference(last) > _refreshInterval;
    if (!hasNew && !expired) return;

    var anySuccess = false;

    // 1) filter v2 推播訂閱。
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
          // 節點版本不相容或未啟用 filter：關掉這條路，退回純輪詢。
          _filterAvailable = false;
          _filterSubscribed = false;
        } else if (response.statusCode < 300) {
          _filterSubscribed = true;
          anySuccess = true;
          _filterFailureCount = 0;
        } else {
          // 5xx（例如 503「No suitable service peer」）：節點本身沒有可用的
          // filter peer，訂閱並未成立。累計失敗次數後直接關閉這條路，否則
          // 每一輪都會去打 filter 快取並換回一堆 400。
          _filterSubscribed = false;
          _filterFailureCount++;
          if (_filterFailureCount >= _filterFailureThreshold) {
            _filterAvailable = false;
          }
        }
      } catch (_) {
        // CORS 或網路問題會導致訂閱被擋掉；連續幾次失敗後關閉 filter，
        // 讓訊息改由 relay / store 兜底，避免 devtools 充滿紅字。
        _filterFailureCount++;
        if (_filterFailureCount >= _filterFailureThreshold) {
          _filterAvailable = false;
        }
      }
    }

    // 2) 優先嘗試靜態分片訂閱：對 waku01 (cluster 10000) 這類靜態分片節點，
    //    直接對 /relay/v1/subscriptions 訂閱 pubsub topic 即可；CORS preflight
    //    已由反向代理正確回應 OPTIONS，因此使用標準的 application/json。
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
          // 節點不支援靜態分片 endpoint，走 auto-sharding fallback。
          _staticEndpointUnavailable = true;
        } else if (response.statusCode < 300) {
          _staticMode = true;
          _staticSubscribed = true;
          anySuccess = true;
        }
      } catch (_) {
        // 網路/CORS 問題：保持 false，下次重試。
      }
    }

    // 3) 靜態分片走不通才走 auto-sharding。
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
          // 節點版本不相容或未啟用 auto-sharding relay。
          _relayAutoAvailable = false;
        } else if (response.statusCode >= 500 &&
            response.body.contains('Static sharding is used')) {
          // 節點使用靜態分片，auto endpoint 不接受純 content topic。
          _staticMode = true;
        } else if (response.statusCode < 300) {
          anySuccess = true;
        }
      } catch (_) {
        // 訂閱失敗不影響主流程，下一輪會再試
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
        .timeout(const Duration(seconds: 10));
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
    // 三個來源都查，合併去重；全部失敗才向上拋錯。
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
      // 1) 即時來源：filter 推播快取。節點已經幫我們把訂閱的訊息收好，
      //    每輪都取，延遲就只取決於輪詢間隔。必須確認訂閱成立過才讀，
      //    否則未訂閱的 topic 會一直回 400。
      if (_filterAvailable && _filterSubscribed) {
        await safe(() => _queryFilterCache(contentTopics));
      }

      // 2) 兜底來源：store（歷史）+ relay 快取。兩者都比 filter 重
      //    （relay 要逐 topic 打一次），所以節流：full 查詢一定做，
      //    其餘每 5 輪做一次，避免漏掉離線期間或沒被推播到的訊息。
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
  /// 呼叫前必須確認 filter 訂閱已成立（`_filterSubscribed`）；未訂閱的 topic
  /// 節點會回 400 `Not subscribed to topic`，那種請求純屬噪音，應在源頭擋掉。
  /// 過程中的其他失敗（逾時、連線中斷）一律視為空，上層還有 store 兜底。
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
  /// - 自動分片模式：逐 content topic 呼叫 `GET /relay/v1/auto/messages/{topic}`；
  ///   404 代表該 topic 暫無快取（或節點未訂閱），視為空而非錯誤。
  /// - 靜態分片模式：一次呼叫 `GET /relay/v1/messages/{pubsubTopic}` 取回該
  ///   shard 的所有訊息，再用 content topic 在本地篩選。
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
    // 沒有 since 時預設回看 48 小時（nwaku 預設 retention 也是 2 天）
    final startMs =
        sinceMs != null && sinceMs > 0 ? sinceMs : nowMs - 48 * 3600 * 1000;
    final response = await _client
        .get(
          _uri('/store/v3/messages', <String, dynamic>{
            'includeData': 'true',
            // 一定要「由新到舊」：沒有 since 的查詢（例如撈金鑰包）預設回看
            // 48 小時，而金鑰包每 2 分鐘重發一次，若取最舊的 N 則永遠只看得到
            // 最早那批，新加入的聯絡人會卡在「同步中」。
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
          // store v3 每筆是 {"messageHash":..,"message":{..},"pubsubTopic":..}
          // 真正的欄位在 "message" 裡面，必須拆開否則會解析出一堆空訊息。
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

  /// 由 `/health` 的內容判斷節點的 relay 是否已入網。
  ///
  /// 只認得 `connectionStatus`；解析失敗（例如 fallback 到 `/debug/v1/info`）
  /// 時回傳 true，避免因為看不懂回應就誤報「無 peer」。
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

/// 傳輸層例外。
@immutable
class WakuTransportException implements Exception {
  const WakuTransportException(this.message);

  final String message;

  @override
  String toString() => 'WakuTransportException: $message';
}

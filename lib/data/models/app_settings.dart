import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/material.dart' show Brightness, ThemeMode;

import '../waku/waku_transport.dart' show TransportKind;
import 'chain.dart';

/// 使用者的主题偏好。
enum ThemePreference {
  system('system'),
  light('light'),
  dark('dark');

  const ThemePreference(this.value);

  final String value;

  static ThemePreference fromValue(String? value) {
    for (final t in ThemePreference.values) {
      if (t.value == value) return t;
    }
    return ThemePreference.system;
  }

  ThemeMode get themeMode {
    switch (this) {
      case ThemePreference.system:
        return ThemeMode.system;
      case ThemePreference.light:
        return ThemeMode.light;
      case ThemePreference.dark:
        return ThemeMode.dark;
    }
  }

  /// 用于偏好预览的亮度（system 时交给系统，这里给日间）。
  Brightness get previewBrightness =>
      this == ThemePreference.dark ? Brightness.dark : Brightness.light;
}

/// 全站设定，持久化于本地储存。
@immutable
class AppSettings {
  /// 预设的区块链：WEB6 联盟链（Contribution / CNT）。
  static const ChainType defaultChain = ChainType.besu;

  const AppSettings({
    this.theme = ThemePreference.system,
    this.localeCode = '',
    this.transport = TransportKind.nwakuRest,
    this.nodeUrls = builtinNodeUrls,
    this.activeNodeUrl = defaultActiveNodeUrl,
    this.rpcOverrides = const <String, String>{},
    this.chain = defaultChain,
    this.nickname = '',
    this.onboarded = false,
    this.lastSyncMs = 0,
  });

  final ThemePreference theme;

  /// 空字串代表跟随系统。
  final String localeCode;

  final TransportKind transport;

  /// 已设定的 nwaku REST 节点清单（内建 + 使用者自订）。
  ///
  /// 这是「可用节点池」，只是候选清单；实际连线的永远只有使用者选取的
  /// 那一台，见 [activeNodeUrl]。[nodeUrls] 只用于设定页列出节点与探测状态。
  final List<String> nodeUrls;

  /// 目前选取（使用中）的节点，也是唯一会被连线的节点。
  final String activeNodeUrl;

  /// 内建节点：不可删除，永远存在于节点清单中。
  static const List<String> builtinNodeUrls = <String>[
    'https://waku01.web6.win',
    'https://waku02.web6.win',
  ];

  /// 预设使用中的节点（等于第一个内建节点）。
  static const String defaultActiveNodeUrl = 'https://waku01.web6.win';

  /// 实际要被连线的节点。
  ///
  /// 通常等于 [activeNodeUrl]；若选取的节点已不在清单中（例如刚被移除），
  /// 退回清单中的第一台，避免连线指向不存在的节点。
  String get resolvedActiveNodeUrl {
    if (nodeUrls.contains(activeNodeUrl)) return activeNodeUrl;
    return nodeUrls.isEmpty ? defaultActiveNodeUrl : nodeUrls.first;
  }

  /// 是否为内建节点（内建节点不可移除）。
  static bool isBuiltinNode(String url) => builtinNodeUrls.contains(url);

  /// 正规化使用者输入的节点位址：补上 scheme、移除结尾斜线。
  ///
  /// 无法解析、没有主机名称，或主机名称含非法字元时回传空字串，
  /// 呼叫端据此显示「节点位址无效」。
  static String normalizeNodeUrl(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return '';
    if (!value.contains('://')) value = 'https://$value';
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return '';
    // `Uri.parse` 相当宽松，连空白都会当成主机名称的一部分，所以这里再检查
    // 一次字元集合，避免「not a url」这类乱输入被存成节点。
    final host = uri.host;
    if (!RegExp(r'^[A-Za-z0-9._:\[\]-]+$').hasMatch(host)) return '';
    return value;
  }

  /// 使用者自订的 RPC / API 端点，键为 [ChainType.id]。
  ///
  /// 用 map 而不是「每条链一个栏位」，新增链时才不用一路改
  /// `copyWith` / `toJson` / `fromJson`；没设定的链就用
  /// [ChainConfig.defaultRpc]。
  final Map<String, String> rpcOverrides;

  /// 钱包目前显示的区块链（仅影响钱包页，不影响聊天身份 did:ethr）。
  final ChainType chain;

  final String nickname;

  final bool onboarded;

  /// 上次同步的时间戳（毫秒），用于增量拉取。
  final int lastSyncMs;

  /// 目前选定链所使用的 RPC / API 端点：使用者自订值，否则用链的预设值。
  String rpcFor(ChainType chain) {
    final own = rpcOverrides[chain.id]?.trim() ?? '';
    return own.isEmpty ? ChainConfig.of(chain).defaultRpc : own;
  }

  AppSettings copyWith({
    ThemePreference? theme,
    String? localeCode,
    TransportKind? transport,
    List<String>? nodeUrls,
    String? activeNodeUrl,
    Map<String, String>? rpcOverrides,
    ChainType? chain,
    String? nickname,
    bool? onboarded,
    int? lastSyncMs,
  }) {
    return AppSettings(
      theme: theme ?? this.theme,
      localeCode: localeCode ?? this.localeCode,
      transport: transport ?? this.transport,
      nodeUrls: nodeUrls ?? this.nodeUrls,
      activeNodeUrl: activeNodeUrl ?? this.activeNodeUrl,
      rpcOverrides: rpcOverrides ?? this.rpcOverrides,
      chain: chain ?? this.chain,
      nickname: nickname ?? this.nickname,
      onboarded: onboarded ?? this.onboarded,
      lastSyncMs: lastSyncMs ?? this.lastSyncMs,
    );
  }

  /// 复写单一链的端点；[url] 为空表示还原成预设值。
  AppSettings withRpc(ChainType chain, String url) {
    final next = Map<String, String>.from(rpcOverrides);
    final value = url.trim();
    if (value.isEmpty) {
      next.remove(chain.id);
    } else {
      next[chain.id] = value;
    }
    return copyWith(rpcOverrides: next);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'theme': theme.value,
        'localeCode': localeCode,
        'transport': transport.value,
        'nodeUrls': nodeUrls,
        'activeNodeUrl': activeNodeUrl,
        'rpcOverrides': rpcOverrides,
        'chain': chain.id,
        'nickname': nickname,
        'onboarded': onboarded,
        'lastSyncMs': lastSyncMs,
      };

  /// 由持久化资料还原节点清单。
  ///
  /// 内建节点永远排在最前面且一定存在；旧版只有单一 `nodeUrl` 时，会被
  /// 并入自订节点，避免使用者升级后设定消失。
  static List<String> _readNodeUrls(Map<dynamic, dynamic> json) {
    final collected = <String>[];

    void add(Object? raw) {
      final url = normalizeNodeUrl(raw is String ? raw : '${raw ?? ''}');
      if (url.isEmpty || collected.contains(url)) return;
      collected.add(url);
    }

    final raw = json['nodeUrls'];
    if (raw is List) {
      for (final item in raw) {
        add(item);
      }
    }
    add(json['nodeUrl']);

    return <String>[
      ...builtinNodeUrls,
      ...collected.where((url) => !builtinNodeUrls.contains(url)),
    ];
  }

  /// 由持久化资料还原「使用中」的节点。
  ///
  /// 旧版没有这个栏位时，预设使用清单中的第一台；若记录的节点已被移除，
  /// 也一并退回第一台，避免设定指向不存在的节点。
  static String _readActiveNode(Map<dynamic, dynamic> json, List<String> urls) {
    final url = normalizeNodeUrl((json['activeNodeUrl'] as String?) ?? '');
    if (url.isNotEmpty && urls.contains(url)) return url;
    return urls.isEmpty ? defaultActiveNodeUrl : urls.first;
  }

  /// 读出使用者自订的 RPC / API 端点。
  ///
  /// 旧版把端点存在 `rpcUrl` / `tronRpcUrl` / `besuRpcUrl` 三个栏位，这里
  /// 一并搬进 [rpcOverrides]，使用者的设定不会因为升级而消失。
  static Map<String, String> _readRpcOverrides(Map<dynamic, dynamic> json) {
    final result = <String, String>{};

    void put(String key, String? value) {
      final text = (value ?? '').trim();
      if (text.isEmpty) return;
      result[key] = text;
    }

    final raw = json['rpcOverrides'];
    if (raw is Map) {
      for (final entry in raw.entries) {
        put('${entry.key}', entry.value as String?);
      }
    }
    put(ChainType.ethereum.id, json['rpcUrl'] as String?);
    put(ChainType.tron.id, json['tronRpcUrl'] as String?);
    put(ChainType.besu.id, json['besuRpcUrl'] as String?);
    return result;
  }

  static AppSettings fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return const AppSettings();
    final nodeUrls = _readNodeUrls(json);
    return AppSettings(
      theme: ThemePreference.fromValue(json['theme'] as String?),
      localeCode: (json['localeCode'] as String?) ?? '',
      transport: TransportKind.fromValue(json['transport'] as String?),
      nodeUrls: nodeUrls,
      activeNodeUrl: _readActiveNode(json, nodeUrls),
      rpcOverrides: _readRpcOverrides(json),
      // 没有记录过链别时（首次安装）用预设的 WEB6；已选过的则照旧，
      // 不因为改了预设值就把老使用者换到别条链上。
      chain: json.containsKey('chain')
          ? ChainType.fromId(json['chain'] as String?)
          : defaultChain,
      nickname: (json['nickname'] as String?) ?? '',
      onboarded: (json['onboarded'] as bool?) ?? false,
      lastSyncMs: (json['lastSyncMs'] as int?) ?? 0,
    );
  }
}

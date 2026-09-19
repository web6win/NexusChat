import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/material.dart' show Brightness, ThemeMode;

import '../waku/waku_transport.dart' show TransportKind;
import 'chain.dart';

/// 使用者的主題偏好。
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

  /// 用於偏好預覽的亮度（system 時交給系統，這裡給日間）。
  Brightness get previewBrightness =>
      this == ThemePreference.dark ? Brightness.dark : Brightness.light;
}

/// 全站設定，持久化於本地儲存。
@immutable
class AppSettings {
  const AppSettings({
    this.theme = ThemePreference.system,
    this.localeCode = '',
    this.transport = TransportKind.nwakuRest,
    this.nodeUrls = builtinNodeUrls,
    this.activeNodeUrl = defaultActiveNodeUrl,
    this.rpcUrl = 'https://ethereum-rpc.publicnode.com',
    this.chain = ChainType.ethereum,
    this.chainName = 'Ethereum Mainnet',
    this.tronRpcUrl = 'https://api.trongrid.io',
    this.besuRpcUrl = 'https://chain.web6.win',
    this.nickname = '',
    this.onboarded = false,
    this.lastSyncMs = 0,
  });

  final ThemePreference theme;

  /// 空字串代表跟隨系統。
  final String localeCode;

  final TransportKind transport;

  /// 已設定的 nwaku REST 節點清單（內建 + 使用者自訂）。
  ///
  /// 這是「可用節點池」，只是候選清單；實際連線的永遠只有使用者選取的
  /// 那一台，見 [activeNodeUrl]。[nodeUrls] 只用於設定頁列出節點與探測狀態。
  final List<String> nodeUrls;

  /// 目前選取（使用中）的節點，也是唯一會被連線的節點。
  final String activeNodeUrl;

  /// 內建節點：不可刪除，永遠存在於節點清單中。
  static const List<String> builtinNodeUrls = <String>[
    'https://waku01.web6.win',
    'https://waku02.web6.win',
  ];

  /// 預設使用中的節點（等於第一個內建節點）。
  static const String defaultActiveNodeUrl = 'https://waku01.web6.win';

  /// 實際要被連線的節點。
  ///
  /// 通常等於 [activeNodeUrl]；若選取的節點已不在清單中（例如剛被移除），
  /// 退回清單中的第一台，避免連線指向不存在的節點。
  String get resolvedActiveNodeUrl {
    if (nodeUrls.contains(activeNodeUrl)) return activeNodeUrl;
    return nodeUrls.isEmpty ? defaultActiveNodeUrl : nodeUrls.first;
  }

  /// 是否為內建節點（內建節點不可移除）。
  static bool isBuiltinNode(String url) => builtinNodeUrls.contains(url);

  /// 正規化使用者輸入的節點位址：補上 scheme、移除結尾斜線。
  ///
  /// 無法解析、沒有主機名稱，或主機名稱含非法字元時回傳空字串，
  /// 呼叫端據此顯示「節點位址無效」。
  static String normalizeNodeUrl(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return '';
    if (!value.contains('://')) value = 'https://$value';
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return '';
    // `Uri.parse` 相當寬鬆，連空白都會當成主機名稱的一部分，所以這裡再檢查
    // 一次字元集合，避免「not a url」這類亂輸入被存成節點。
    final host = uri.host;
    if (!RegExp(r'^[A-Za-z0-9._:\[\]-]+$').hasMatch(host)) return '';
    return value;
  }

  /// 以太坊 JSON-RPC 端點（查餘額、ENS）。
  final String rpcUrl;

  /// 錢包目前顯示的區塊鏈（僅影響錢包頁，不影響聊天身份 did:ethr）。
  final ChainType chain;

  final String chainName;

  /// TRON API 端點（TronGrid 或相容全節點）。
  final String tronRpcUrl;

  /// Besu 聯盟鏈（WEB6）的 JSON-RPC 端點。
  final String besuRpcUrl;

  final String nickname;

  final bool onboarded;

  /// 上次同步的時間戳（毫秒），用於增量拉取。
  final int lastSyncMs;

  /// 目前選定鏈所使用的 RPC / API 端點。
  String rpcFor(ChainType chain) => switch (chain) {
        ChainType.ethereum => rpcUrl,
        ChainType.tron => tronRpcUrl,
        ChainType.besu => besuRpcUrl,
      };

  AppSettings copyWith({
    ThemePreference? theme,
    String? localeCode,
    TransportKind? transport,
    List<String>? nodeUrls,
    String? activeNodeUrl,
    String? rpcUrl,
    ChainType? chain,
    String? chainName,
    String? tronRpcUrl,
    String? besuRpcUrl,
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
      rpcUrl: rpcUrl ?? this.rpcUrl,
      chain: chain ?? this.chain,
      chainName: chainName ?? this.chainName,
      tronRpcUrl: tronRpcUrl ?? this.tronRpcUrl,
      besuRpcUrl: besuRpcUrl ?? this.besuRpcUrl,
      nickname: nickname ?? this.nickname,
      onboarded: onboarded ?? this.onboarded,
      lastSyncMs: lastSyncMs ?? this.lastSyncMs,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'theme': theme.value,
        'localeCode': localeCode,
        'transport': transport.value,
        'nodeUrls': nodeUrls,
        'activeNodeUrl': activeNodeUrl,
        'rpcUrl': rpcUrl,
        'chain': chain.id,
        'chainName': chainName,
        'tronRpcUrl': tronRpcUrl,
        'besuRpcUrl': besuRpcUrl,
        'nickname': nickname,
        'onboarded': onboarded,
        'lastSyncMs': lastSyncMs,
      };

  /// 由持久化資料還原節點清單。
  ///
  /// 內建節點永遠排在最前面且一定存在；舊版只有單一 `nodeUrl` 時，會被
  /// 併入自訂節點，避免使用者升級後設定消失。
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

  /// 由持久化資料還原「使用中」的節點。
  ///
  /// 舊版沒有這個欄位時，預設使用清單中的第一台；若記錄的節點已被移除，
  /// 也一併退回第一台，避免設定指向不存在的節點。
  static String _readActiveNode(Map<dynamic, dynamic> json, List<String> urls) {
    final url = normalizeNodeUrl((json['activeNodeUrl'] as String?) ?? '');
    if (url.isNotEmpty && urls.contains(url)) return url;
    return urls.isEmpty ? defaultActiveNodeUrl : urls.first;
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
      rpcUrl: (json['rpcUrl'] as String?) ??
          'https://ethereum-rpc.publicnode.com',
      chain: ChainType.fromId(json['chain'] as String?),
      chainName: (json['chainName'] as String?) ?? 'Ethereum Mainnet',
      tronRpcUrl:
          (json['tronRpcUrl'] as String?) ?? 'https://api.trongrid.io',
      besuRpcUrl:
          (json['besuRpcUrl'] as String?) ?? 'https://chain.web6.win',
      nickname: (json['nickname'] as String?) ?? '',
      onboarded: (json['onboarded'] as bool?) ?? false,
      lastSyncMs: (json['lastSyncMs'] as int?) ?? 0,
    );
  }
}

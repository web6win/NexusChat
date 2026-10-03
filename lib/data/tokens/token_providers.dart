import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chain.dart';
import '../models/token_def.dart';

/// 內建通證設定：來自 `assets/tokens.json`，依鏈分組。
///
/// 設定檔以 `ChainType.id` 為鍵（例如 `ethereum` / `besu`），陣列內每個
/// 物件描述一個通證的名稱、符號、標準、精度、合約地址、圖示與顏色。
final builtInTokensProvider =
    FutureProvider<Map<ChainType, List<TokenDef>>>((ref) async {
  final raw = await rootBundle.loadString('assets/tokens.json');
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final result = <ChainType, List<TokenDef>>{};
  decoded.forEach((key, value) {
    final chain = ChainType.fromId(key);
    final list = (value as List<dynamic>)
        .map((e) => TokenDef.fromJson(e as Map<String, dynamic>))
        .toList();
    result[chain] = list;
  });
  return result;
});

/// 自訂通證設定檔（shared_preferences）的鍵名。
const _customPrefsKey = 'custom_tokens_v1';

/// 使用者自訂通證（跨鏈），持久化於 shared_preferences。
final customTokensProvider = NotifierProvider<CustomTokensNotifier,
    Map<ChainType, List<TokenDef>>>(CustomTokensNotifier.new);

class CustomTokensNotifier extends Notifier<Map<ChainType, List<TokenDef>>> {
  @override
  Map<ChainType, List<TokenDef>> build() {
    // 非同步載入，初始為空；載入完成後會透過 state 更新觸發重建。
    _load();
    return const <ChainType, List<TokenDef>>{};
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_customPrefsKey);
    if (raw == null || raw.isEmpty) {
      state = const <ChainType, List<TokenDef>>{};
      return;
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final result = <ChainType, List<TokenDef>>{};
      decoded.forEach((key, value) {
        final chain = ChainType.fromId(key);
        final list = (value as List<dynamic>)
            .map((e) =>
                TokenDef.fromJson(e as Map<String, dynamic>).copyWith(custom: true))
            .toList();
        result[chain] = list;
      });
      state = result;
    } catch (_) {
      state = const <ChainType, List<TokenDef>>{};
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = <String, dynamic>{};
    state.forEach((chain, list) {
      encoded[chain.id] = list.map((t) => t.toJson()).toList();
    });
    await prefs.setString(_customPrefsKey, jsonEncode(encoded));
  }

  /// 新增自訂通證；同一合約地址或代號不重複加入。
  void add(ChainType chain, TokenDef token) {
    final existing = state[chain] ?? <TokenDef>[];
    final next = <TokenDef>[
      ...existing.where((t) =>
          t.address.toLowerCase() != token.address.toLowerCase() &&
          t.symbol.toLowerCase() != token.symbol.toLowerCase()),
      token.copyWith(custom: true),
    ];
    state = <ChainType, List<TokenDef>>{...state, chain: next};
    _persist();
  }

  /// 移除某條鏈上指定合約地址的自訂通證。
  void remove(ChainType chain, String address) {
    final existing = state[chain] ?? <TokenDef>[];
    final next = existing
        .where((t) => t.address.toLowerCase() != address.toLowerCase())
        .toList();
    state = <ChainType, List<TokenDef>>{...state, chain: next};
    _persist();
  }
}

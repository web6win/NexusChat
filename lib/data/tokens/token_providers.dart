import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chain.dart';
import '../models/token_def.dart';

/// 内建通证设定：来自 `assets/tokens.json`，依链分组。
///
/// 设定档以 `ChainType.id` 为键（例如 `ethereum` / `besu`），阵列内每个
/// 物件描述一个通证的名称、符号、标准、精度、合约地址、图示与颜色。
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

/// 自订通证设定档（shared_preferences）的键名。
const _customPrefsKey = 'custom_tokens_v1';

/// 使用者自订通证（跨链），持久化于 shared_preferences。
final customTokensProvider = NotifierProvider<CustomTokensNotifier,
    Map<ChainType, List<TokenDef>>>(CustomTokensNotifier.new);

class CustomTokensNotifier extends Notifier<Map<ChainType, List<TokenDef>>> {
  @override
  Map<ChainType, List<TokenDef>> build() {
    // 非同步载入，初始为空；载入完成后会透过 state 更新触发重建。
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

  /// 新增自订通证；同一合约地址或代号不重复加入。
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

  /// 移除某条链上指定合约地址的自订通证。
  void remove(ChainType chain, String address) {
    final existing = state[chain] ?? <TokenDef>[];
    final next = existing
        .where((t) => t.address.toLowerCase() != address.toLowerCase())
        .toList();
    state = <ChainType, List<TokenDef>>{...state, chain: next};
    _persist();
  }
}

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 一笔代币转帐的本地记录（仅记录「本 App 发起」的送出，不含链上查询）。
///
/// 这是一种轻量的本机历史：不依赖任何区块链浏览器索引服务，因此
/// ERC-20 与 TRC-20 都能用同一套逻辑。链上真正的确认状态仍以浏览器为准。
class TokenTxRecord {
  const TokenTxRecord({
    required this.chainId,
    required this.symbol,
    required this.contract,
    required this.toAddress,
    required this.amount,
    required this.hash,
    required this.timestamp,
    required this.standard,
    this.explorerUrl,
  });

  final String chainId;
  final String symbol;
  final String contract;
  final String toAddress;
  final double amount;
  final String hash;
  final int timestamp;
  final String standard;
  final String? explorerUrl;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'chainId': chainId,
        'symbol': symbol,
        'contract': contract,
        'toAddress': toAddress,
        'amount': amount,
        'hash': hash,
        'timestamp': timestamp,
        'standard': standard,
        'explorerUrl': explorerUrl,
      };

  static TokenTxRecord fromJson(Map<String, dynamic> json) => TokenTxRecord(
        chainId: json['chainId'] as String,
        symbol: json['symbol'] as String,
        contract: json['contract'] as String,
        toAddress: json['toAddress'] as String,
        amount: (json['amount'] as num).toDouble(),
        hash: json['hash'] as String,
        timestamp: json['timestamp'] as int,
        standard: json['standard'] as String,
        explorerUrl: json['explorerUrl'] as String?,
      );
}

/// 本地代币转帐记录（shared_preferences）的键名。
const _historyPrefsKey = 'token_tx_history_v1';

/// 本地代币转帐历史（本 App 发起的送出），依时间倒序，最多保留 100 笔。
final tokenTxHistoryProvider = NotifierProvider<TokenTxHistoryNotifier,
    List<TokenTxRecord>>(TokenTxHistoryNotifier.new);

class TokenTxHistoryNotifier extends Notifier<List<TokenTxRecord>> {
  @override
  List<TokenTxRecord> build() {
    _load();
    return const <TokenTxRecord>[];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyPrefsKey);
    if (raw == null || raw.isEmpty) {
      state = const <TokenTxRecord>[];
      return;
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      state = decoded
          .map((e) => TokenTxRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      state = const <TokenTxRecord>[];
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _historyPrefsKey,
      jsonEncode(state.map((r) => r.toJson()).toList()),
    );
  }

  /// 新增一笔记录（置顶），并限制总量以避免无限成长。
  void add(TokenTxRecord record) {
    state = <TokenTxRecord>[
      record,
      ...state,
    ].take(100).toList();
    _persist();
  }

  /// 清空全部记录。
  void clear() {
    state = const <TokenTxRecord>[];
    _persist();
  }
}

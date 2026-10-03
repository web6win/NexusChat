import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 一筆代幣轉帳的本地記錄（僅記錄「本 App 發起」的送出，不含鏈上查詢）。
///
/// 這是一種輕量的本機歷史：不依賴任何區塊鏈瀏覽器索引服務，因此
/// ERC-20 與 TRC-20 都能用同一套邏輯。鏈上真正的確認狀態仍以瀏覽器為準。
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

/// 本地代幣轉帳記錄（shared_preferences）的鍵名。
const _historyPrefsKey = 'token_tx_history_v1';

/// 本地代幣轉帳歷史（本 App 發起的送出），依時間倒序，最多保留 100 筆。
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

  /// 新增一筆記錄（置頂），並限制總量以避免無限成長。
  void add(TokenTxRecord record) {
    state = <TokenTxRecord>[
      record,
      ...state,
    ].take(100).toList();
    _persist();
  }

  /// 清空全部記錄。
  void clear() {
    state = const <TokenTxRecord>[];
    _persist();
  }
}

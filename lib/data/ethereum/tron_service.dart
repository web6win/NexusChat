import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart' show immutable;

import '../crypto/tron_address.dart';
import '../models/chain.dart';
import 'chain_account.dart';

/// 與 TRON 生態互動的唯讀服務：查 TRX 餘額。
///
/// 走 TronGrid HTTP API（`/wallet/getaccount`）。餘額以 SUN 回傳，
/// 1 TRX = 1,000,000 SUN。所有方法都容錯：API 失敗時回傳 null，
/// 不影響聊天主流程。
@immutable
class TronService {
  TronService({required this.apiUrl, http.Client? client})
      : _client = client ?? http.Client();

  /// TronGrid（或其他相容全節點）的 base URL。
  final String apiUrl;

  final http.Client _client;

  bool get isConfigured => apiUrl.trim().isNotEmpty;

  void dispose() => _client.close();

  /// 取得地址的 TRX 餘額（單位：TRX）。
  ///
  /// 帳戶未激活（鏈上不存在）時 `getaccount` 不回傳 `balance` 欄位，
  /// 視為餘額 0。
  Future<double?> getBalanceTrx(String base58Address) async {
    if (!isConfigured) return null;
    try {
      final response = await _client
          .post(
            Uri.parse('$apiUrl/wallet/getaccount'),
            headers: <String, String>{'content-type': 'application/json'},
            body: jsonEncode(<String, dynamic>{
              'address': base58Address,
              'visible': true,
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final raw = data['balance'];
      if (raw == null) return 0.0;
      return (raw as num).toDouble() / 1e6;
    } catch (_) {
      return null;
    }
  }

  /// 一次取得餘額，回傳統一結構。
  Future<ChainAccountInfo> summary(String base58Address) async {
    if (!isConfigured || !TronAddress.isValid(base58Address)) {
      return ChainAccountInfo(
        chain: ChainType.tron,
        address: base58Address,
        error: 'no-rpc',
      );
    }
    final balance = await getBalanceTrx(base58Address);
    return ChainAccountInfo(
      chain: ChainType.tron,
      address: base58Address,
      // 查詢失敗視為「無法取得」，保留錯誤狀態；未激活帳戶則為 0。
      balanceNative: balance,
      chainId: null,
      error: balance == null ? 'network' : null,
    );
  }
}

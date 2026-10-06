import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart' show immutable;

import '../crypto/tron_address.dart';
import '../models/chain.dart';
import 'chain_account.dart';

/// 与 TRON 生态互动的唯读服务：查 TRX 余额。
///
/// 走 TronGrid HTTP API（`/wallet/getaccount`）。余额以 SUN 回传，
/// 1 TRX = 1,000,000 SUN。所有方法都容错：API 失败时回传 null，
/// 不影响聊天主流程。
@immutable
class TronService {
  TronService({required this.apiUrl, http.Client? client})
      : _client = client ?? http.Client();

  /// TronGrid（或其他相容全节点）的 base URL。
  final String apiUrl;

  final http.Client _client;

  bool get isConfigured => apiUrl.trim().isNotEmpty;

  void dispose() => _client.close();

  /// 取得地址的 TRX 余额（单位：TRX）。
  ///
  /// 帐户未激活（链上不存在）时 `getaccount` 不回传 `balance` 栏位，
  /// 视为余额 0。
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

  /// 一次取得余额，回传统一结构。
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
      // 查询失败视为「无法取得」，保留错误状态；未激活帐户则为 0。
      balanceNative: balance,
      chainId: null,
      error: balance == null ? 'network' : null,
    );
  }
}

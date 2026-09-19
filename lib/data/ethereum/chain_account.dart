import 'package:meta/meta.dart' show immutable;

import '../models/chain.dart';

/// 錢包頁的帳戶資訊（餘額 / chain id / 域名）。
///
/// 統一以太坊與 TRON 兩條鏈的回傳結構，取代原本僅供以太坊使用的
/// [EthereumAccountInfo]。
@immutable
class ChainAccountInfo {
  const ChainAccountInfo({
    required this.chain,
    required this.address,
    this.balanceNative,
    this.domainName,
    this.chainId,
    this.error,
  });

  final ChainType chain;

  /// 顯示用地址：以太坊為 0x…（EIP-55），TRON 為 T…（Base58Check）。
  final String address;

  /// 原生代幣餘額（單位：ETH 或 TRX）。
  final double? balanceNative;

  /// 域名（ENS 名稱 / TRON 域名），無則為 null。
  final String? domainName;

  /// 鏈 ID。以太坊為數值；TRON 主網無 EVM 式 chainId，故為 null。
  final int? chainId;

  final String? error;

  bool get hasBalance => balanceNative != null;
}

import 'package:meta/meta.dart' show immutable;

import '../models/chain.dart';

/// 钱包页的帐户资讯（余额 / chain id / 域名）。
///
/// 统一以太坊与 TRON 两条链的回传结构，取代原本仅供以太坊使用的
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

  /// 显示用地址：以太坊为 0x…（EIP-55），TRON 为 T…（Base58Check）。
  final String address;

  /// 原生代币余额（单位：ETH 或 TRX）。
  final double? balanceNative;

  /// 域名（ENS 名称 / TRON 域名），无则为 null。
  final String? domainName;

  /// 链 ID。以太坊为数值；TRON 主网无 EVM 式 chainId，故为 null。
  final int? chainId;

  final String? error;

  bool get hasBalance => balanceNative != null;
}

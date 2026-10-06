import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:web3dart/crypto.dart' show keccak256;
import 'package:web3dart/web3dart.dart';

import '../crypto/did.dart';
import '../models/chain.dart';
import 'chain_account.dart';

/// ENS 主网注册表地址（所有网路上皆相同）。
const String _ensRegistryAddress = '0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e';

/// 正向解析：ENS 名称 → 地址。

/// 与以太坊生态互动的服务：查余额、chain id、ENS 正反向解析。
///
/// 所有方法都容错：RPC 失败时回传 null，不影响聊天主流程。
class EthereumService {
  EthereumService({
    required this.rpcUrl,
    http.Client? client,
    this.chain = ChainType.ethereum,
    this.enableEns = true,
  }) : _client = client ?? http.Client();

  final String rpcUrl;

  /// 这组 RPC 属于哪条链（用以标记回传结果）。
  final ChainType chain;

  /// 是否启用 ENS 解析。联盟链 / 私有链通常没有 ENS 合约，
  /// 关掉可省下两次必定失败的 RPC 往返。
  final bool enableEns;

  final http.Client _client;

  Web3Client? _web3;

  Web3Client get _client3 {
    _web3 ??= Web3Client(rpcUrl, _client);
    return _web3!;
  }

  bool get isConfigured => rpcUrl.trim().isNotEmpty;

  /// 更新 RPC 端点后需要重建客户端。
  void reset() {
    _web3?.dispose();
    _web3 = null;
  }

  void dispose() {
    _web3?.dispose();
    _client.close();
  }

  /// 取得地址的 ETH 余额。
  Future<double?> getBalance(String address) async {
    if (!isConfigured) return null;
    try {
      final result = await _client3
          .getBalance(EthereumAddress.fromHex(Did.toAddress(address)))
          .timeout(const Duration(seconds: 12));
      return result.getValueInUnit(EtherUnit.ether);
    } catch (_) {
      return null;
    }
  }

  Future<int?> getChainId() async {
    if (!isConfigured) return null;
    try {
      final id = await _client3
          .getChainId()
          .timeout(const Duration(seconds: 10));
      return id.toInt();
    } catch (_) {
      return null;
    }
  }

  /// ENS 正向解析：`vitalik.eth` → `0x...`
  Future<String?> resolveEns(String name) async {
    if (!isConfigured || !enableEns) return null;
    if (!Did.isEnsName(name)) return null;
    try {
      final node = namehash(name.trim().toLowerCase());
      final resolverAddress = await _registryCall('resolver', [node]);
      if (resolverAddress == null) return null;
      final resolver = _resolverContract(resolverAddress);
      final result = await _client3
          .call(
            contract: resolver,
            function: resolver.function('addr'),
            params: [node],
          )
          .timeout(const Duration(seconds: 12));
      final value = result.first;
      if (value is EthereumAddress) {
        final hex = value.hexEip55;
        return _isZeroAddress(hex) ? null : hex;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// ENS 反向解析：`0x...` → `vitalik.eth`
  Future<String?> reverseLookup(String address) async {
    if (!isConfigured || !enableEns) return null;
    try {
      final node = namehash(
        '${Did.toAddress(address).toLowerCase().replaceFirst('0x', '')}.addr.reverse',
      );
      final resolverAddress = await _registryCall('resolver', [node]);
      if (resolverAddress == null) return null;
      final resolver = _resolverContract(resolverAddress);
      final result = await _client3
          .call(
            contract: resolver,
            function: resolver.function('name'),
            params: [node],
          )
          .timeout(const Duration(seconds: 12));
      final value = result.first;
      if (value is String && value.isNotEmpty) return value;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 一次取得余额、chain id 与 ENS 名称，回传统一结构。
  Future<ChainAccountInfo> summary(String address, {String? ensHint}) async {
    if (!isConfigured) {
      return ChainAccountInfo(
        chain: chain,
        address: address,
        error: 'no-rpc',
      );
    }
    final results = await Future.wait<Object?>(<Future<Object?>>[
      getBalance(address),
      getChainId(),
      ensHint != null && ensHint.isNotEmpty
          ? Future<String?>.value(ensHint)
          : reverseLookup(address),
    ]);
    return ChainAccountInfo(
      chain: chain,
      address: address,
      balanceNative: results[0] is double ? results[0]! as double : null,
      chainId: results[1] is int ? results[1]! as int : null,
      domainName: results[2] is String ? results[2]! as String : null,
    );
  }

  Future<EthereumAddress?> _registryCall(
    String functionName,
    List<dynamic> params,
  ) async {
    final registry = _registryContract();
    final result = await _client3
        .call(
          contract: registry,
          function: registry.function(functionName),
          params: params,
        )
        .timeout(const Duration(seconds: 12));
    final value = result.first;
    if (value is! EthereumAddress) return null;
    if (_isZeroAddress(value.hex)) return null;
    return value;
  }

  DeployedContract _registryContract() => DeployedContract(
        ContractAbi.fromJson(_registryAbi, 'ENSRegistry'),
        EthereumAddress.fromHex(_ensRegistryAddress),
      );

  DeployedContract _resolverContract(EthereumAddress address) =>
      DeployedContract(
        ContractAbi.fromJson(_resolverAbi, 'PublicResolver'),
        address,
      );

  static bool _isZeroAddress(String hex) =>
      hex.replaceAll('0', '').toLowerCase() == 'x' ||
      hex.toLowerCase() == '0x0000000000000000000000000000000000000000';

  /// EIP-137 namehash。
  static Uint8List namehash(String name) {
    var node = Uint8List(32);
    if (name.isEmpty) return node;
    final labels = name.split('.').reversed.toList(growable: false);
    for (final label in labels) {
      final labelHash = keccak256(utf8.encode(label));
      node = keccak256(
        Uint8List.fromList(<int>[...node, ...labelHash]),
      );
    }
    return node;
  }
}

const String _registryAbi = '''
[
  {
    "inputs": [{"internalType": "bytes32", "name": "node", "type": "bytes32"}],
    "name": "resolver",
    "outputs": [{"internalType": "address", "name": "", "type": "address"}],
    "stateMutability": "view",
    "type": "function"
  }
]
''';

const String _resolverAbi = '''
[
  {
    "inputs": [{"internalType": "bytes32", "name": "node", "type": "bytes32"}],
    "name": "addr",
    "outputs": [{"internalType": "address", "name": "", "type": "address"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "bytes32", "name": "node", "type": "bytes32"}],
    "name": "name",
    "outputs": [{"internalType": "string", "name": "", "type": "string"}],
    "stateMutability": "view",
    "type": "function"
  }
]
''';

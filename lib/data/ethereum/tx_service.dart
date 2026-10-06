import 'dart:convert';
import 'dart:math' show pow;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:http/http.dart' as http;
import 'package:web3dart/crypto.dart'
    show MsgSignature, bytesToHex, hexToBytes, sign, unsignedIntToBytes;
import 'package:web3dart/web3dart.dart';

import '../crypto/did.dart';
import '../crypto/tron_address.dart';
import '../models/chain.dart';

/// 交易失败时抛出，[code] 为可直接映射成 i18n 的代码。
///
/// 可能的值：`no-rpc` / `invalid-address` / `invalid-amount` /
/// `insufficient-funds` / `network`。
class TxException implements Exception {
  const TxException(this.code);

  final String code;

  @override
  String toString() => code;
}

/// 广播成功后的结果。
class TxResult {
  const TxResult({required this.hash, this.explorerUrl});

  final String hash;

  /// 区块浏览器连结（该链未设定时为 null）。
  final String? explorerUrl;
}

/// 链上原生代币转帐：EVM 系（以太坊 / Besu 联盟链）与 TRON。
///
/// 不含 ERC-20 / TRC-20 代币转帐。
abstract final class TxService {
  /// 依链检查地址格式。
  static bool isValidAddress(ChainType chain, String address) =>
      chain == ChainType.tron
          ? TronAddress.isValid(address)
          : Did.isAddress(address);

  /// 依链分派转帐。
  static Future<TxResult> send({
    required ChainType chain,
    required String rpcUrl,
    required String privateKeyHex,
    required String toAddress,
    required double amount,
    String? explorerBase,
    http.Client? client,
  }) {
    switch (chain) {
      // 所有 EVM 链走同一条路径：同一把私钥、同一个 0x 地址、同一套 JSON-RPC。
      case ChainType.ethereum:
      case ChainType.base:
      case ChainType.arbitrum:
      case ChainType.bsc:
      case ChainType.besu:
        return sendEvm(
          rpcUrl: rpcUrl,
          privateKeyHex: privateKeyHex,
          toAddress: toAddress,
          amountEther: amount,
          explorerBase: explorerBase,
          client: client,
        );
      case ChainType.tron:
        return sendTron(
          apiUrl: rpcUrl,
          privateKeyHex: privateKeyHex,
          toAddress: toAddress,
          amountTrx: amount,
          explorerBase: explorerBase,
          client: client,
        );
    }
  }

  /// EVM 系转帐。[amountEther] 为人类可读数量（0.5 → 0.5 ETH）。
  static Future<TxResult> sendEvm({
    required String rpcUrl,
    required String privateKeyHex,
    required String toAddress,
    required double amountEther,
    String? explorerBase,
    http.Client? client,
  }) async {
    if (rpcUrl.trim().isEmpty) throw const TxException('no-rpc');
    if (!Did.isAddress(toAddress)) throw const TxException('invalid-address');
    if (amountEther <= 0) throw const TxException('invalid-amount');

    final ownsClient = client == null;
    final httpClient = client ?? http.Client();
    final web3 = Web3Client(rpcUrl, httpClient);
    try {
      final credentials = EthPrivateKey(hexToBytes(privateKeyHex));
      final to = EthereumAddress.fromHex(Did.toAddress(toAddress));
      final value = EtherAmount.fromBigInt(
        EtherUnit.wei,
        BigInt.from((amountEther * 1e18).round()),
      );

      // 先做本地检查，避免白付手续费。
      final balance = await web3
          .getBalance(credentials.address)
          .timeout(const Duration(seconds: 15));
      if (balance.getInWei < value.getInWei) {
        throw const TxException('insufficient-funds');
      }

      final chainId =
          (await web3.getChainId().timeout(const Duration(seconds: 15)))
              .toInt();
      final gasPrice =
          await web3.getGasPrice().timeout(const Duration(seconds: 15));

      final hash = await web3.sendTransaction(
        credentials,
        Transaction(to: to, value: value, gasPrice: gasPrice),
        chainId: chainId,
      );
      return TxResult(hash: hash, explorerUrl: _explorer(explorerBase, hash));
    } on TxException {
      rethrow;
    } catch (error) {
      throw TxException(_classify('$error'));
    } finally {
      if (ownsClient) {
        web3.dispose();
        httpClient.close();
      }
    }
  }

  /// TRON 转帐：`/wallet/createtransaction` 取交易骨架 → 本地 secp256k1
  /// 签章 → `/wallet/broadcasttransaction` 广播。
  ///
  /// TRON 的交易 id 是 `sha256(raw_data)`，而 `ref_block_bytes` /
  /// `expiration` 等栏位由节点产生，因此必须先向节点索取未签名交易。
  static Future<TxResult> sendTron({
    required String apiUrl,
    required String privateKeyHex,
    required String toAddress,
    required double amountTrx,
    String? explorerBase,
    http.Client? client,
  }) async {
    if (apiUrl.trim().isEmpty) throw const TxException('no-rpc');
    if (!TronAddress.isValid(toAddress)) {
      throw const TxException('invalid-address');
    }
    if (amountTrx <= 0) throw const TxException('invalid-amount');

    final ownsClient = client == null;
    final httpClient = client ?? http.Client();
    final base = apiUrl.replaceAll(RegExp(r'/+$'), '');
    const headers = <String, String>{'content-type': 'application/json'};
    final credentials = EthPrivateKey(hexToBytes(privateKeyHex));
    // owner 必须是 21 位元组的 `41…` 形式（0x41 + 20 位元组地址），
    // 不能只给 20 位元组的以太坊地址。
    final ownerHex = '41${bytesToHex(credentials.address.addressBytes)}';

    try {
      // 1) 本地预检余额，避免白付频宽／能量。
      final accountResp = await httpClient
          .post(
            Uri.parse('$base/wallet/getaccount'),
            headers: headers,
            body: jsonEncode(<String, dynamic>{
              'address': ownerHex,
              'visible': false,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (accountResp.statusCode == 200) {
        final account = jsonDecode(accountResp.body) as Map<String, dynamic>;
        // 帐户不存在时无 balance 栏位，代表余额为 0。
        final balanceSun = (account['balance'] as num?)?.toDouble() ?? 0;
        // 需额外保留少量 TRX 作为频宽／手续费。
        const feeReserveSun = 1e6;
        if (balanceSun < amountTrx * 1e6 + feeReserveSun) {
          throw const TxException('insufficient-funds');
        }
      }

      // 2) 取得未签名交易骨架。
      final created = await httpClient
          .post(
            Uri.parse('$base/wallet/createtransaction'),
            headers: headers,
            body: jsonEncode(<String, dynamic>{
              'owner_address': ownerHex,
              'to_address': TronAddress.toHex(toAddress),
              'amount': (amountTrx * 1e6).round(),
              'visible': false,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (created.statusCode != 200) throw const TxException('network');
      final decoded = jsonDecode(created.body) as Map<String, dynamic>;
      final rawTransaction = decoded['transaction'];
      if (rawTransaction is! Map) throw const TxException('network');
      final transaction =
          Map<String, dynamic>.from(rawTransaction);
      final rawHex = transaction['raw_data_hex'] as String?;
      if (rawHex == null || rawHex.isEmpty) {
        throw const TxException('network');
      }

      // 3) txID = sha256(raw_data)，再以私钥对这个「杂凑本身」签章。
      //
      // 注意：不能用 EthPrivateKey.signToUint8List —— 它内部会再过一次
      // keccak256，那是以太坊个人讯息签章的语意。TRON 要求的是对 txID
      // 直接做 secp256k1 ECDSA，所以改用低阶的 secp256k1.sign。
      final txId = Uint8List.fromList(
        sha256.convert(hexToBytes(rawHex)).bytes,
      );
      final signature = sign(txId, credentials.privateKey);
      transaction['signature'] = <String>[packSignature(signature)];

      // 4) 广播。
      final broadcast = await httpClient
          .post(
            Uri.parse('$base/wallet/broadcasttransaction'),
            headers: headers,
            body: jsonEncode(transaction),
          )
          .timeout(const Duration(seconds: 20));
      if (broadcast.statusCode != 200) throw const TxException('network');
      final result = jsonDecode(broadcast.body) as Map<String, dynamic>;
      if (result['result'] != true) {
        throw TxException(_classifyTron('${result['code']}'));
      }
      final hash = bytesToHex(txId);
      return TxResult(hash: hash, explorerUrl: _explorer(explorerBase, hash));
    } on TxException {
      rethrow;
    } catch (_) {
      throw const TxException('network');
    } finally {
      if (ownsClient) httpClient.close();
    }
  }

  /// ERC-20 最小 ABI：只需 `transfer` 与 `balanceOf` 两个函式。
  static const String _erc20Abi = '''
[
  {"constant":false,"inputs":[{"name":"to","type":"address"},{"name":"value","type":"uint256"}],
   "name":"transfer","outputs":[{"name":"","type":"bool"}],"type":"function"},
  {"constant":true,"inputs":[{"name":"who","type":"address"}],"name":"balanceOf",
   "outputs":[{"name":"","type":"uint256"}],"type":"function"}
]''';

  /// ERC-20 代币转帐（仅 EVM 系：以太坊 / Base / Arbitrum / BSC / Besu）。
  ///
  /// [amount] 为人类可读数量（如 `1.5` → `1.5 * 10^decimals`），
  /// 会先本地预检代币余额，避免白付 gas。TRON 的 TRC-20 走另一套合约呼叫，
  /// 这里直接抛 `unsupported`。
  static Future<TxResult> sendErc20({
    required ChainType chain,
    required String rpcUrl,
    required String privateKeyHex,
    required String contractAddress,
    required String toAddress,
    required double amount,
    required int decimals,
    String? explorerBase,
    http.Client? client,
  }) async {
    if (chain == ChainType.tron) throw const TxException('unsupported');
    if (rpcUrl.trim().isEmpty) throw const TxException('no-rpc');
    if (!Did.isAddress(toAddress) || !Did.isAddress(contractAddress)) {
      throw const TxException('invalid-address');
    }
    if (amount <= 0) throw const TxException('invalid-amount');

    final ownsClient = client == null;
    final httpClient = client ?? http.Client();
    final web3 = Web3Client(rpcUrl, httpClient);
    try {
      final credentials = EthPrivateKey(hexToBytes(privateKeyHex));
      final contract = DeployedContract(
        ContractAbi.fromJson(_erc20Abi, 'ERC20'),
        EthereumAddress.fromHex(Did.toAddress(contractAddress)),
      );
      final transferFn = contract.function('transfer');
      final value = BigInt.from((amount * pow(10, decimals)).round());

      // 本地预检代币余额，避免白付 gas。
      final balanceFn = contract.function('balanceOf');
      final balRes = await web3
          .call(
            contract: contract,
            function: balanceFn,
            params: <dynamic>[credentials.address],
          )
          .timeout(const Duration(seconds: 15));
      final balance = balRes.first as BigInt;
      if (balance < value) throw const TxException('insufficient-funds');

      final chainId =
          (await web3.getChainId().timeout(const Duration(seconds: 15)))
              .toInt();
      final gasPrice =
          await web3.getGasPrice().timeout(const Duration(seconds: 15));
      final hash = await web3.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: contract,
          function: transferFn,
          parameters: <dynamic>[
            EthereumAddress.fromHex(Did.toAddress(toAddress)),
            value,
          ],
          gasPrice: gasPrice,
        ),
        chainId: chainId,
      );
      return TxResult(hash: hash, explorerUrl: _explorer(explorerBase, hash));
    } on TxException {
      rethrow;
    } catch (error) {
      throw TxException(_classify('$error'));
    } finally {
      if (ownsClient) {
        web3.dispose();
        httpClient.close();
      }
    }
  }

  /// 查询 ERC-20 代币余额（人类可读），查不到时回传 null。
  ///
  /// 仅 EVM 系；TRON 或无 RPC / 离线时回传 null（画面就不显示可用余额）。
  static Future<double?> erc20Balance({
    required ChainType chain,
    required String rpcUrl,
    required String contractAddress,
    required String ownerAddress,
    required int decimals,
    http.Client? client,
  }) async {
    if (chain == ChainType.tron) return null;
    if (rpcUrl.trim().isEmpty) return null;
    if (!Did.isAddress(contractAddress) || !Did.isAddress(ownerAddress)) {
      return null;
    }
    final ownsClient = client == null;
    final httpClient = client ?? http.Client();
    final web3 = Web3Client(rpcUrl, httpClient);
    try {
      final contract = DeployedContract(
        ContractAbi.fromJson(_erc20Abi, 'ERC20'),
        EthereumAddress.fromHex(Did.toAddress(contractAddress)),
      );
      final balanceFn = contract.function('balanceOf');
      final res = await web3
          .call(
            contract: contract,
            function: balanceFn,
            params: <dynamic>[
              EthereumAddress.fromHex(Did.toAddress(ownerAddress))
            ],
          )
          .timeout(const Duration(seconds: 15));
      final raw = res.first as BigInt;
      return raw / BigInt.from(10).pow(decimals);
    } catch (_) {
      return null;
    } finally {
      if (ownsClient) {
        web3.dispose();
        httpClient.close();
      }
    }
  }

  /// TRC-20 代币转帐（TRON）。
  ///
  /// 走 TRON 的「触发智慧合约」流程：`/wallet/triggersmartcontract` 取交易骨架
  /// → 本地 secp256k1 签章（与原生 TRON 相同，对 txID 签章 + low-S）
  /// → `/wallet/broadcasttransaction` 广播。`function_selector` 为
  /// `transfer(address,uint256)`，`parameter` 为收款地址（左补至 32 位元组）
  /// 与金额（uint256 大端）拼接的 128 hex。
  static Future<TxResult> sendTrc20({
    required String apiUrl,
    required String privateKeyHex,
    required String contractAddress,
    required String toAddress,
    required double amount,
    required int decimals,
    String? explorerBase,
    http.Client? client,
  }) async {
    if (apiUrl.trim().isEmpty) throw const TxException('no-rpc');
    if (!TronAddress.isValid(toAddress) ||
        !TronAddress.isValid(contractAddress)) {
      throw const TxException('invalid-address');
    }
    if (amount <= 0) throw const TxException('invalid-amount');

    final ownsClient = client == null;
    final httpClient = client ?? http.Client();
    final base = apiUrl.replaceAll(RegExp(r'/+$'), '');
    const headers = <String, String>{'content-type': 'application/json'};
    final credentials = EthPrivateKey(hexToBytes(privateKeyHex));
    // owner 必须是 21 位元组的 `41…` 形式（0x41 + 20 位元组地址），
    // 不能只给 20 位元组的以太坊地址。
    final ownerHex = '41${bytesToHex(credentials.address.addressBytes)}';

    try {
      // 1) 本地预检代币余额（balanceOf）。
      final balance = await _trc20Call(
        httpClient,
        base,
        headers,
        ownerHex: ownerHex,
        contractAddress: contractAddress,
        function: 'balanceOf(address)',
        parameter: _tronAddressParam(toAddress),
      );
      final value = BigInt.from((amount * pow(10, decimals)).round());
      if (balance < value) throw const TxException('insufficient-funds');

      // 2) 触发合约交易骨架。
      final created = await httpClient
          .post(
            Uri.parse('$base/wallet/triggersmartcontract'),
            headers: headers,
            body: jsonEncode(<String, dynamic>{
              'owner_address': ownerHex,
              'contract_address': TronAddress.toHex(contractAddress),
              'function_selector': 'transfer(address,uint256)',
              'parameter':
                  _tronAddressParam(toAddress) + _tronUintParam(value),
              'visible': false,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (created.statusCode != 200) throw const TxException('network');
      final decoded = jsonDecode(created.body) as Map<String, dynamic>;
      final rawTransaction = decoded['transaction'];
      if (rawTransaction is! Map) throw const TxException('network');
      final transaction = Map<String, dynamic>.from(rawTransaction);
      final rawHex = transaction['raw_data_hex'] as String?;
      if (rawHex == null || rawHex.isEmpty) throw const TxException('network');

      // 3) 签章（与原生 TRON 同：对 txID 做 secp256k1 ECDSA + low-S）。
      final txId = Uint8List.fromList(
        sha256.convert(hexToBytes(rawHex)).bytes,
      );
      final signature = sign(txId, credentials.privateKey);
      transaction['signature'] = <String>[packSignature(signature)];

      // 4) 广播。
      final broadcast = await httpClient
          .post(
            Uri.parse('$base/wallet/broadcasttransaction'),
            headers: headers,
            body: jsonEncode(transaction),
          )
          .timeout(const Duration(seconds: 20));
      if (broadcast.statusCode != 200) throw const TxException('network');
      final result = jsonDecode(broadcast.body) as Map<String, dynamic>;
      if (result['result'] != true) {
        throw TxException(_classifyTron('${result['code']}'));
      }
      final hash = bytesToHex(txId);
      return TxResult(hash: hash, explorerUrl: _explorer(explorerBase, hash));
    } on TxException {
      rethrow;
    } catch (_) {
      throw const TxException('network');
    } finally {
      if (ownsClient) httpClient.close();
    }
  }

  /// 查询 TRC-20 代币余额（人类可读），查不到时回传 null。
  static Future<double?> trc20Balance({
    required String apiUrl,
    required String contractAddress,
    required String ownerAddress,
    required int decimals,
    http.Client? client,
  }) async {
    if (apiUrl.trim().isEmpty) return null;
    if (!TronAddress.isValid(ownerAddress) ||
        !TronAddress.isValid(contractAddress)) {
      return null;
    }
    final ownsClient = client == null;
    final httpClient = client ?? http.Client();
    final base = apiUrl.replaceAll(RegExp(r'/+$'), '');
    // owner 必须是 21 位元组的 `41…` 形式（TronAddress.toHex 已含 0x41）。
    final ownerHex = TronAddress.toHex(ownerAddress);
    try {
      final raw = await _trc20Call(
        httpClient,
        base,
        const <String, String>{'content-type': 'application/json'},
        ownerHex: ownerHex,
        contractAddress: contractAddress,
        function: 'balanceOf(address)',
        parameter: _tronAddressParam(ownerAddress),
      );
      return raw / BigInt.from(10).pow(decimals);
    } catch (_) {
      return null;
    } finally {
      if (ownsClient) httpClient.close();
    }
  }

  /// 呼叫 TRC-20 的唯读函式（目前用于 balanceOf）。
  ///
  /// 透过 `/wallet/triggerconstantcontract` 取得 `constant_result`（uint256 的
  /// 32 位元组 hex），解析为 BigInt。
  static Future<BigInt> _trc20Call(
    http.Client httpClient,
    String base,
    Map<String, String> headers, {
    required String ownerHex,
    required String contractAddress,
    required String function,
    required String parameter,
  }) async {
    final resp = await httpClient
        .post(
          Uri.parse('$base/wallet/triggerconstantcontract'),
          headers: headers,
          body: jsonEncode(<String, dynamic>{
            'owner_address': ownerHex,
            'contract_address': TronAddress.toHex(contractAddress),
            'function_selector': function,
            'parameter': parameter,
            'visible': false,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) throw const TxException('network');
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final result = decoded['constant_result'];
    if (result is! List || result.isEmpty) return BigInt.zero;
    final hex = result.first as String;
    if (hex.isEmpty) return BigInt.zero;
    return BigInt.parse(hex, radix: 16);
  }

  /// 把 Base58 TRON 地址编码成 TRC-20 参数用的 32 位元组（64 hex，左补零）。
  static String _tronAddressParam(String base58) {
    final h = TronAddress.toHex(base58); // 21 位元组 → 42 hex。
    return h.padLeft(64, '0');
  }

  /// 把 uint256 金额编码成 32 位元组（64 hex，大端、左补零）。
  static String _tronUintParam(BigInt value) {
    var hex = value.toRadixString(16);
    if (hex.length.isOdd) hex = '0$hex';
    return hex.padLeft(64, '0');
  }

  /// 依链分派代币（ERC-20 / TRC-20）转帐。
  static Future<TxResult> sendToken({
    required ChainType chain,
    required String rpcUrl,
    required String privateKeyHex,
    required String contractAddress,
    required String toAddress,
    required double amount,
    required int decimals,
    String? explorerBase,
    http.Client? client,
  }) {
    if (chain == ChainType.tron) {
      return sendTrc20(
        apiUrl: rpcUrl,
        privateKeyHex: privateKeyHex,
        contractAddress: contractAddress,
        toAddress: toAddress,
        amount: amount,
        decimals: decimals,
        explorerBase: explorerBase,
        client: client,
      );
    }
    return sendErc20(
      chain: chain,
      rpcUrl: rpcUrl,
      privateKeyHex: privateKeyHex,
      contractAddress: contractAddress,
      toAddress: toAddress,
      amount: amount,
      decimals: decimals,
      explorerBase: explorerBase,
      client: client,
    );
  }

  /// 依链分派代币余额查询（ERC-20 / TRC-20）。
  static Future<double?> tokenBalance({
    required ChainType chain,
    required String rpcUrl,
    required String contractAddress,
    required String ownerAddress,
    required int decimals,
    http.Client? client,
  }) {
    if (chain == ChainType.tron) {
      return trc20Balance(
        apiUrl: rpcUrl,
        contractAddress: contractAddress,
        ownerAddress: ownerAddress,
        decimals: decimals,
        client: client,
      );
    }
    return erc20Balance(
      chain: chain,
      rpcUrl: rpcUrl,
      contractAddress: contractAddress,
      ownerAddress: ownerAddress,
      decimals: decimals,
      client: client,
    );
  }

  /// secp256k1 曲线阶 N。
  static final BigInt _curveOrder = BigInt.parse(
    'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141',
    radix: 16,
  );

  /// low-S 规约的界线（`N >> 1`）。
  static final BigInt _halfCurveOrder = _curveOrder >> 1;

  /// 把签章打包成 TRON 要求的 `r‖s‖v` 65 位元组 hex。
  ///
  /// 这里有两个必须处理的差异，否则节点会直接拒绝广播：
  ///
  /// 1. **v 的语意**：`sign()` 走以太坊惯例，回传 27/28；TRON 的第 65 位元组
  ///    只接受恢复识别码（0/1），因此要先减掉 27。
  /// 2. **low-S**：java-tron 会验证签章是否为 canonical（`s <= N/2`），
  ///    high-S 一律拒收。取 `N - s` 时恢复识别码必须同时反转（0↔1），
  ///    否则会还原出另一个公钥，被节点判成「签章与 owner 不符」。
  static String packSignature(MsgSignature signature) {
    final recoveryId = signature.v >= 27 ? signature.v - 27 : signature.v;
    // 理论上恒为 0/1；若上游语意改变，宁可当成网路错误也不要写出坏签章。
    if (recoveryId < 0 || recoveryId > 1) throw const TxException('network');

    var s = signature.s;
    var v = recoveryId;
    if (s > _halfCurveOrder) {
      s = _curveOrder - s;
      v = 1 - v;
    }

    final r = padUint8ListTo32(unsignedIntToBytes(signature.r));
    final sBytes = padUint8ListTo32(unsignedIntToBytes(s));
    final out = Uint8List(65)
      ..setRange(0, 32, r)
      ..setRange(32, 64, sBytes)
      ..[64] = v;
    return bytesToHex(out);
  }

  static String _classify(String message) {
    final text = message.toLowerCase();
    if (text.contains('insufficient') ||
        text.contains('funds') ||
        text.contains('balance')) {
      return 'insufficient-funds';
    }
    return 'network';
  }

  static String _classifyTron(String code) {
    switch (code) {
      // 帐户频宽/能量不足，或手续费不足。
      case 'BANDWIDTH_ERROR':
      case 'BANDWITH_ERROR':
      case 'ENERGY_ERROR':
      case 'CONTRACT_VALIDATE_ERROR':
      case 'BALANCE_NOT_SUFFICIENT':
      case 'ACCOUNT_RESOURCE_LIMIT':
        return 'insufficient-funds';
      // 交易骨架过期（ref_block 太旧），重新建构即可。
      case 'TRANSACTION_EXPIRED':
      case 'DUP_TRANSACTION_ERROR':
        return 'network';
      default:
        return 'network';
    }
  }

  static String? _explorer(String? base, String hash) {
    if (base == null || base.isEmpty) return null;
    final trimmed = base.replaceAll(RegExp(r'/+$'), '');
    return '$trimmed/search?q=$hash';
  }
}

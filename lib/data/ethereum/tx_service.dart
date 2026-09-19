import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:http/http.dart' as http;
import 'package:web3dart/crypto.dart'
    show MsgSignature, bytesToHex, hexToBytes, sign, unsignedIntToBytes;
import 'package:web3dart/web3dart.dart';

import '../crypto/did.dart';
import '../crypto/tron_address.dart';
import '../models/chain.dart';

/// 交易失敗時拋出，[code] 為可直接映射成 i18n 的代碼。
///
/// 可能的值：`no-rpc` / `invalid-address` / `invalid-amount` /
/// `insufficient-funds` / `network`。
class TxException implements Exception {
  const TxException(this.code);

  final String code;

  @override
  String toString() => code;
}

/// 廣播成功後的結果。
class TxResult {
  const TxResult({required this.hash, this.explorerUrl});

  final String hash;

  /// 區塊瀏覽器連結（該鏈未設定時為 null）。
  final String? explorerUrl;
}

/// 鏈上原生代幣轉帳：EVM 系（以太坊 / Besu 聯盟鏈）與 TRON。
///
/// 不含 ERC-20 / TRC-20 代幣轉帳。
abstract final class TxService {
  /// 依鏈檢查地址格式。
  static bool isValidAddress(ChainType chain, String address) =>
      chain == ChainType.tron
          ? TronAddress.isValid(address)
          : Did.isAddress(address);

  /// 依鏈分派轉帳。
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
      case ChainType.ethereum:
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

  /// EVM 系轉帳。[amountEther] 為人類可讀數量（0.5 → 0.5 ETH）。
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

      // 先做本地檢查，避免白付手續費。
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

  /// TRON 轉帳：`/wallet/createtransaction` 取交易骨架 → 本地 secp256k1
  /// 簽章 → `/wallet/broadcasttransaction` 廣播。
  ///
  /// TRON 的交易 id 是 `sha256(raw_data)`，而 `ref_block_bytes` /
  /// `expiration` 等欄位由節點產生，因此必須先向節點索取未簽名交易。
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
    final ownerHex = bytesToHex(credentials.address.addressBytes);

    try {
      // 1) 本地預檢餘額，避免白付頻寬／能量。
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
        // 帳戶不存在時無 balance 欄位，代表餘額為 0。
        final balanceSun = (account['balance'] as num?)?.toDouble() ?? 0;
        // 需額外保留少量 TRX 作為頻寬／手續費。
        const feeReserveSun = 1e6;
        if (balanceSun < amountTrx * 1e6 + feeReserveSun) {
          throw const TxException('insufficient-funds');
        }
      }

      // 2) 取得未簽名交易骨架。
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

      // 3) txID = sha256(raw_data)，再以私鑰對這個「雜湊本身」簽章。
      //
      // 注意：不能用 EthPrivateKey.signToUint8List —— 它內部會再過一次
      // keccak256，那是以太坊個人訊息簽章的語意。TRON 要求的是對 txID
      // 直接做 secp256k1 ECDSA，所以改用低階的 secp256k1.sign。
      final txId = Uint8List.fromList(
        sha256.convert(hexToBytes(rawHex)).bytes,
      );
      final signature = sign(txId, credentials.privateKey);
      transaction['signature'] = <String>[_packSignature(signature)];

      // 4) 廣播。
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

  /// 把簽章打包成 TRON 要求的 `r‖s‖v` 65 位元組 hex。
  ///
  /// TRON 的 v 就是 secp256k1 的 recovery id（0/1），不是 EIP-155 的 chainId
  /// 變體，因此這裡直接使用 `sign()` 回傳的 `v`（已是 27/28 偏移）。
  static String _packSignature(MsgSignature signature) {
    final r = padUint8ListTo32(unsignedIntToBytes(signature.r));
    final s = padUint8ListTo32(unsignedIntToBytes(signature.s));
    final out = Uint8List(65)
      ..setRange(0, 32, r)
      ..setRange(32, 64, s)
      ..[64] = signature.v;
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
      // 帳戶頻寬/能量不足，或手續費不足。
      case 'BANDWIDTH_ERROR':
      case 'BANDWITH_ERROR':
      case 'ENERGY_ERROR':
      case 'CONTRACT_VALIDATE_ERROR':
      case 'BALANCE_NOT_SUFFICIENT':
      case 'ACCOUNT_RESOURCE_LIMIT':
        return 'insufficient-funds';
      // 交易骨架過期（ref_block 太舊），重新建構即可。
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

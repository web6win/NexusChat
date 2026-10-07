import 'dart:convert';
import 'dart:typed_data';

import 'package:bip32/bip32.dart' as bip32;
import 'package:bip39/bip39.dart' as bip39;
import 'package:cryptography/cryptography.dart';
import 'package:meta/meta.dart' show immutable;
import 'package:web3dart/credentials.dart' show EthPrivateKey;
import 'package:web3dart/crypto.dart' show privateKeyToPublic;

import '../../core/utils/hex.dart';
import 'did.dart';
import 'tron_address.dart';

/// 一组完整的本地身份：助记词 → BIP39 种子 → BIP32 派生 → 以太坊金钥 + DID。
///
/// 派生路径：
/// - `m/44'/60'/0'/0/0`：以太坊帐户（同时决定 did:ethr 身份）
/// - `m/44'/195'/0'/0/0`：波场（TRON）帐户，coin type 195 为波场标准
/// - `m/10016'/0'`：NexusChat 专用的 X25519 讯息加密金钥（与 EVM 帐户路径隔离）
@immutable
class AppIdentity {
  const AppIdentity({
    required this.mnemonic,
    required this.did,
    required this.address,
    required this.tronAddress,
    required this.ethPrivateHex,
    required this.ethPublicHex,
    required this.tronPrivateHex,
    required this.encSeedHex,
    required this.encPublicKeyB64,
    this.passphrase = '',
    required this.createdAt,
  });

  /// 波场（TRON）的 BIP44 推导路径。
  ///
  /// SLIP-44 中 TRON 的 coin type 是 **195**，TronLink 与波场官方钱包都使用
  /// `m/44'/195'/0'/0/0`。早期版本误用以太坊路径（60'）来编码波场地址，
  /// 导致同一组助记词在 TronLink 显示的地址与本 App 不同；这里改为标准路径。
  static const String tronPath = "m/44'/195'/0'/0/0";

  /// BIP39 助记词（12 / 24 个单字）。
  final String mnemonic;

  /// `did:ethr:0x...`
  final String did;

  /// 以太坊地址（小写，含 0x）。
  final String address;

  /// TRON 地址（T 开头 Base58Check），由 [tronPath] 派生的那把钥匙编码而来。
  final String tronAddress;

  /// secp256k1 私钥（hex，不含 0x）。
  final String ethPrivateHex;

  /// secp256k1 公钥（64 位元组未压缩表示不含前缀，hex）。
  final String ethPublicHex;

  /// 波场专用私钥（hex，不含 0x），由 [tronPath] 派生。
  ///
  /// 波场交易签章**必须**用这把钥匙，不能拿 [ethPrivateHex]：
  /// 签章与 owner_address 不符时，节点会直接拒绝广播。
  final String tronPrivateHex;

  /// X25519 加密金钥种子（32 位元组，hex）。
  final String encSeedHex;

  /// X25519 公钥（Base64），会发布到 Waku 供他人加密讯息给自己。
  final String encPublicKeyB64;

  /// BIP39 密码短语（第 13 / 25 个词），可为空。
  ///
  /// 助记词 + 密码短语共同决定 BIP39 种子：**同一组助记词配上不同短语，
  /// 会得到完全不同的身份**。它与助记词同等重要，必须一起备份；
  /// 这里视为秘密材料，只写进保险库的密文里。
  final String passphrase;

  final DateTime createdAt;

  /// 熵强度 128 → 12 个助记词。
  static Future<AppIdentity> generate({
    int strength = 128,
    String passphrase = '',
  }) {
    final mnemonic = bip39.generateMnemonic(strength: strength);
    return fromMnemonic(mnemonic, passphrase: passphrase);
  }

  /// 由助记词重建身份；助记词无效时抛出 [FormatException]。
  ///
  /// [passphrase] 为 BIP39 的可选密码短语（区分大小写与空白）。
  static Future<AppIdentity> fromMnemonic(
    String mnemonic, {
    String passphrase = '',
  }) async {
    final normalized = mnemonic.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (!bip39.validateMnemonic(normalized)) {
      throw const FormatException('invalid bip39 mnemonic');
    }

    final seed = bip39.mnemonicToSeed(normalized, passphrase: passphrase);
    final root = bip32.BIP32.fromSeed(seed);

    final ethNode = root.derivePath("m/44'/60'/0'/0/0");
    final ethKey = EthPrivateKey(_pad32(ethNode.privateKey!));
    final address = '0x${Hex.encode(ethKey.address.addressBytes)}';

    final encNode = root.derivePath("m/10016'/0'");
    final encSeed = _pad32(encNode.privateKey!);
    final encPair = await X25519().newKeyPairFromSeed(encSeed);
    final encPub = await encPair.extractPublicKey();

    // 波场走自己的标准路径（coin type 195），与 TronLink 一致。
    final tron = _deriveTron(normalized, passphrase);

    return AppIdentity(
      mnemonic: normalized,
      did: Did.fromAddress(address),
      address: address,
      tronAddress: tron.address,
      ethPrivateHex: Hex.encode(ethKey.privateKey),
      ethPublicHex: Hex.encode(privateKeyToPublic(ethKey.privateKeyInt)),
      tronPrivateHex: tron.privateHex,
      encSeedHex: Hex.encode(encSeed),
      encPublicKeyB64: B64.encode(encPub.bytes),
      passphrase: passphrase,
      createdAt: DateTime.now().toUtc(),
    );
  }

  /// 由既有私钥（hex）建立身份，用于汇入外部钱包 / 硬体钱包 / 外部签章器。
  ///
  /// 接受 32 位元组（64 个 hex 字元）的 secp256k1 私钥，可带 `0x` 前缀。
  /// 格式不合法或超出曲线阶（N）时抛出 [FormatException]。
  static Future<AppIdentity> fromPrivateKeyHex(String privateHex) async {
    final keyBytes = _parsePrivateKey(privateHex);
    final key = EthPrivateKey(keyBytes);
    final address = '0x${Hex.encode(key.address.addressBytes)}';
    // 以私钥本身派生一组稳定的加密种子，确保每次结果一致。
    final encSeed = Uint8List.fromList(
      (await Sha256().hash(keyBytes + utf8.encode('nexuschat/enc/v1'))).bytes,
    );
    final encPair = await X25519().newKeyPairFromSeed(encSeed);
    final encPub = await encPair.extractPublicKey();
    final tron = TronAddress.fromPublicKeyHex(
      Hex.encode(privateKeyToPublic(key.privateKeyInt)),
    );
    return AppIdentity(
      mnemonic: '',
      did: Did.fromAddress(address),
      address: address,
      tronAddress: tron,
      ethPrivateHex: Hex.encode(key.privateKey),
      ethPublicHex: Hex.encode(privateKeyToPublic(key.privateKeyInt)),
      // 汇入私钥的身份没有推导路径，波场就共用同一把钥匙 ——
      // 这与把同一把私钥汇入 TronLink 的结果一致。
      tronPrivateHex: Hex.encode(key.privateKey),
      encSeedHex: Hex.encode(encSeed),
      encPublicKeyB64: B64.encode(encPub.bytes),
      // 私钥汇入没有助记词，自然也没有密码短语。
      passphrase: '',
      createdAt: DateTime.now().toUtc(),
    );
  }

  /// secp256k1 曲线阶（N）。私钥必须落在 `[1, N-1]`。
  static final BigInt _curveOrder = BigInt.parse(
    'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141',
    radix: 16,
  );

  /// 宽松解析私钥：容许 `0x` 前缀、空白与大小写，并验证长度与范围。
  ///
  /// 回传 32 位元组的私钥；不合法时抛出 [FormatException]。
  static Uint8List _parsePrivateKey(String privateHex) {
    var value = privateHex.trim().replaceAll(RegExp(r'\s+'), '');
    if (value.startsWith('0x') || value.startsWith('0X')) {
      value = value.substring(2);
    }
    if (value.isEmpty || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(value)) {
      throw const FormatException('private key must be hexadecimal');
    }
    // 64 个 hex 字元 = 32 位元组；允许前导零被截短，但不可超过。
    if (value.length > 64) {
      throw const FormatException('private key too long');
    }
    final padded = value.padLeft(64, '0');
    final intValue = BigInt.parse(padded, radix: 16);
    if (intValue == BigInt.zero || intValue >= _curveOrder) {
      throw const FormatException('private key out of range');
    }
    return Hex.decode(padded);
  }

  /// 检查私钥字串是否可汇入（供 UI 即时验证用）。
  static bool isValidPrivateKey(String privateHex) {
    try {
      _parsePrivateKey(privateHex);
      return true;
    } on FormatException {
      return false;
    }
  }

  /// 由私钥推导对应的以太坊地址（小写含 `0x`）。
  ///
  /// 供汇入页做即时预览，比 [fromPrivateKeyHex] 轻量——不做 X25519 派生。
  /// 私钥不合法时抛出 [FormatException]。
  static String addressFromPrivateKey(String privateHex) {
    final key = EthPrivateKey(_parsePrivateKey(privateHex));
    return '0x${Hex.encode(key.address.addressBytes)}';
  }

  /// 由助记词推导波场钥匙（同步，不需要非同步的密码学运算）。
  ///
  /// 供建立身份与「旧身份迁移」共用：既有身份在载入时会重新用标准路径
  /// 推导一次，于是自动改用与 TronLink 相同的地址。
  static ({String address, String privateHex}) _deriveTron(
    String mnemonic,
    String passphrase,
  ) {
    final seed = bip39.mnemonicToSeed(mnemonic, passphrase: passphrase);
    final root = bip32.BIP32.fromSeed(seed);
    final node = root.derivePath(tronPath);
    final key = EthPrivateKey(_pad32(node.privateKey!));
    return (
      address: TronAddress.fromPublicKeyHex(
        Hex.encode(privateKeyToPublic(key.privateKeyInt)),
      ),
      privateHex: Hex.encode(key.privateKey),
    );
  }

  /// 左侧补零至 32 位元组，避免 BIP32 丢弃前导零。
  static Uint8List _pad32(Uint8List input) {
    if (input.length == 32) return input;
    final out = Uint8List(32);
    out.setRange(32 - input.length, 32, input);
    return out;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'mnemonic': mnemonic,
        'did': did,
        'address': address,
        'tronAddress': tronAddress,
        'ethPrivateHex': ethPrivateHex,
        'ethPublicHex': ethPublicHex,
        'tronPrivateHex': tronPrivateHex,
        'encSeedHex': encSeedHex,
        'encPublicKeyB64': encPublicKeyB64,
        // 秘密材料：只会出现在保险库的密文里，绝不进公开提示。
        'passphrase': passphrase,
        'createdAt': createdAt.toIso8601String(),
      };

  static AppIdentity fromJson(Map<dynamic, dynamic> json) {
    final created = json['createdAt'];
    final ethPublicHex = json['ethPublicHex'] as String;
    final mnemonic = (json['mnemonic'] ?? '') as String;
    final passphrase = (json['passphrase'] ?? '') as String;
    final savedTron = json['tronAddress'];
    var tronAddress = savedTron is String ? savedTron : '';
    var tronPrivateHex = (json['tronPrivateHex'] as String?) ?? '';

    if (mnemonic.isNotEmpty) {
      // 助记词身份：一律改用波场标准路径（coin type 195），与 TronLink 一致。
      // 这会覆盖旧版用以太坊路径（60'）存下来的地址 —— 旧地址上的资产仍在
      // 链上，只是本 App 不再显示。
      final derived = _deriveTron(mnemonic, passphrase);
      tronAddress = derived.address;
      tronPrivateHex = derived.privateHex;
    } else if (tronPrivateHex.isEmpty) {
      // 汇入私钥的身份（或无助记词的旧资料）：波场共用以太坊钥匙。
      tronPrivateHex = json['ethPrivateHex'] as String;
      if (tronAddress.isEmpty) {
        tronAddress = TronAddress.fromPublicKeyHex(ethPublicHex);
      }
    }

    return AppIdentity(
      mnemonic: mnemonic,
      did: json['did'] as String,
      address: json['address'] as String,
      tronAddress: tronAddress,
      ethPrivateHex: json['ethPrivateHex'] as String,
      ethPublicHex: ethPublicHex,
      tronPrivateHex: tronPrivateHex,
      encSeedHex: json['encSeedHex'] as String,
      encPublicKeyB64: json['encPublicKeyB64'] as String,
      // 旧版密文没有这个栏位，视为未使用密码短语。
      passphrase: (json['passphrase'] ?? '') as String,
      createdAt: created is String
          ? DateTime.tryParse(created) ?? DateTime.now().toUtc()
          : DateTime.now().toUtc(),
    );
  }

  /// 是否具备可备份的助记词（私钥汇入的身份没有）。
  bool get hasMnemonic => mnemonic.isNotEmpty;

  /// 是否使用 BIP39 密码短语。
  ///
  /// 只有助记词身份才可能带短语；备份时必须连同短语一起保存，
  /// 少了它，助记词会还原出**另一个**身份。
  bool get hasPassphrase => hasMnemonic && passphrase.isNotEmpty;

  /// 是否持有可签章 / 解密的秘密材料。
  ///
  /// 用于「公开提示」物件：只描述身份而不含任何秘密，锁屏时也能安全显示。
  bool get hasSecrets => ethPrivateHex.isNotEmpty && encSeedHex.isNotEmpty;

  /// 完整序列化（**含助记词与私钥**）。
  ///
  /// 这份 JSON 只允许写进经过 [Vault] 加密的密文里，绝不可明文落地。
  Map<String, dynamic> toSecretJson() => toJson();

  /// 公开提示：仅含对外可见、本来就会发布到网路的资讯。
  ///
  /// 用途是在「尚未解锁」的状态下判断身份是否存在、显示帐户地址、
  /// 以及决定路由。这些栏位即使被读走也不构成泄漏 ——
  /// `did` 与 `address` 本来就是公开识别码，`encPublicKeyB64` 也会广播给联络人。
  Map<String, dynamic> toHintJson() => <String, dynamic>{
        'did': did,
        'address': address,
        'tronAddress': tronAddress,
        'encPublicKeyB64': encPublicKeyB64,
        'hasMnemonic': hasMnemonic,
        'createdAt': createdAt.toIso8601String(),
      };

  /// 由密文解出的完整资料还原身份。
  static AppIdentity fromSecretJson(Map<String, dynamic> json) =>
      fromJson(json);
}

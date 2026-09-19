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

/// 一組完整的本地身份：助記詞 → BIP39 種子 → BIP32 派生 → 以太坊金鑰 + DID。
///
/// 派生路徑：
/// - `m/44'/60'/0'/0/0`：以太坊帳戶（同時決定 did:ethr 身份）
/// - `m/10016'/0'`：NexusChat 專用的 X25519 訊息加密金鑰（與 EVM 帳戶路徑隔離）
@immutable
class AppIdentity {
  const AppIdentity({
    required this.mnemonic,
    required this.did,
    required this.address,
    required this.tronAddress,
    required this.ethPrivateHex,
    required this.ethPublicHex,
    required this.encSeedHex,
    required this.encPublicKeyB64,
    required this.createdAt,
  });

  /// BIP39 助記詞（12 / 24 個單字）。
  final String mnemonic;

  /// `did:ethr:0x...`
  final String did;

  /// 以太坊地址（小寫，含 0x）。
  final String address;

  /// TRON 地址（T 開頭 Base58Check）。
  /// 由同一把 secp256k1 公鑰派生，與 [address] 指向同一個帳戶。
  final String tronAddress;

  /// secp256k1 私鑰（hex，不含 0x）。
  final String ethPrivateHex;

  /// secp256k1 公鑰（64 位元組未壓縮表示不含前綴，hex）。
  final String ethPublicHex;

  /// X25519 加密金鑰種子（32 位元組，hex）。
  final String encSeedHex;

  /// X25519 公鑰（Base64），會發布到 Waku 供他人加密訊息給自己。
  final String encPublicKeyB64;

  final DateTime createdAt;

  /// 熵強度 128 → 12 個助記詞。
  static Future<AppIdentity> generate({int strength = 128}) {
    final mnemonic = bip39.generateMnemonic(strength: strength);
    return fromMnemonic(mnemonic);
  }

  /// 由助記詞重建身份；助記詞無效時拋出 [FormatException]。
  static Future<AppIdentity> fromMnemonic(String mnemonic) async {
    final normalized = mnemonic.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (!bip39.validateMnemonic(normalized)) {
      throw const FormatException('invalid bip39 mnemonic');
    }

    final seed = bip39.mnemonicToSeed(normalized);
    final root = bip32.BIP32.fromSeed(seed);

    final ethNode = root.derivePath("m/44'/60'/0'/0/0");
    final ethKey = EthPrivateKey(_pad32(ethNode.privateKey!));
    final address = '0x${Hex.encode(ethKey.address.addressBytes)}';

    final encNode = root.derivePath("m/10016'/0'");
    final encSeed = _pad32(encNode.privateKey!);
    final encPair = await X25519().newKeyPairFromSeed(encSeed);
    final encPub = await encPair.extractPublicKey();

    final tron = TronAddress.fromPublicKeyHex(
      Hex.encode(privateKeyToPublic(ethKey.privateKeyInt)),
    );

    return AppIdentity(
      mnemonic: normalized,
      did: Did.fromAddress(address),
      address: address,
      tronAddress: tron,
      ethPrivateHex: Hex.encode(ethKey.privateKey),
      ethPublicHex: Hex.encode(privateKeyToPublic(ethKey.privateKeyInt)),
      encSeedHex: Hex.encode(encSeed),
      encPublicKeyB64: B64.encode(encPub.bytes),
      createdAt: DateTime.now().toUtc(),
    );
  }

  /// 由既有私鑰（hex）建立身份，用於匯入外部錢包 / 硬體錢包 / 外部簽章器。
  ///
  /// 接受 32 位元組（64 個 hex 字元）的 secp256k1 私鑰，可帶 `0x` 前綴。
  /// 格式不合法或超出曲線階（N）時拋出 [FormatException]。
  static Future<AppIdentity> fromPrivateKeyHex(String privateHex) async {
    final keyBytes = _parsePrivateKey(privateHex);
    final key = EthPrivateKey(keyBytes);
    final address = '0x${Hex.encode(key.address.addressBytes)}';
    // 以私鑰本身派生一組穩定的加密種子，確保每次結果一致。
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
      encSeedHex: Hex.encode(encSeed),
      encPublicKeyB64: B64.encode(encPub.bytes),
      createdAt: DateTime.now().toUtc(),
    );
  }

  /// secp256k1 曲線階（N）。私鑰必須落在 `[1, N-1]`。
  static final BigInt _curveOrder = BigInt.parse(
    'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141',
    radix: 16,
  );

  /// 寬鬆解析私鑰：容許 `0x` 前綴、空白與大小寫，並驗證長度與範圍。
  ///
  /// 回傳 32 位元組的私鑰；不合法時拋出 [FormatException]。
  static Uint8List _parsePrivateKey(String privateHex) {
    var value = privateHex.trim().replaceAll(RegExp(r'\s+'), '');
    if (value.startsWith('0x') || value.startsWith('0X')) {
      value = value.substring(2);
    }
    if (value.isEmpty || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(value)) {
      throw const FormatException('private key must be hexadecimal');
    }
    // 64 個 hex 字元 = 32 位元組；允許前導零被截短，但不可超過。
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

  /// 檢查私鑰字串是否可匯入（供 UI 即時驗證用）。
  static bool isValidPrivateKey(String privateHex) {
    try {
      _parsePrivateKey(privateHex);
      return true;
    } on FormatException {
      return false;
    }
  }

  /// 由私鑰推導對應的以太坊地址（小寫含 `0x`）。
  ///
  /// 供匯入頁做即時預覽，比 [fromPrivateKeyHex] 輕量——不做 X25519 派生。
  /// 私鑰不合法時拋出 [FormatException]。
  static String addressFromPrivateKey(String privateHex) {
    final key = EthPrivateKey(_parsePrivateKey(privateHex));
    return '0x${Hex.encode(key.address.addressBytes)}';
  }

  /// 左側補零至 32 位元組，避免 BIP32 丟棄前導零。
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
        'encSeedHex': encSeedHex,
        'encPublicKeyB64': encPublicKeyB64,
        'createdAt': createdAt.toIso8601String(),
      };

  static AppIdentity fromJson(Map<dynamic, dynamic> json) {
    final created = json['createdAt'];
    final ethPublicHex = json['ethPublicHex'] as String;
    final savedTron = json['tronAddress'];
    // 兼容舊版備份：若沒有 tronAddress，就用公鑰即時派生。
    final tronAddress = savedTron is String && savedTron.isNotEmpty
        ? savedTron
        : TronAddress.fromPublicKeyHex(ethPublicHex);
    return AppIdentity(
      mnemonic: (json['mnemonic'] ?? '') as String,
      did: json['did'] as String,
      address: json['address'] as String,
      tronAddress: tronAddress,
      ethPrivateHex: json['ethPrivateHex'] as String,
      ethPublicHex: ethPublicHex,
      encSeedHex: json['encSeedHex'] as String,
      encPublicKeyB64: json['encPublicKeyB64'] as String,
      createdAt: created is String
          ? DateTime.tryParse(created) ?? DateTime.now().toUtc()
          : DateTime.now().toUtc(),
    );
  }

  /// 是否具備可備份的助記詞（私鑰匯入的身份沒有）。
  bool get hasMnemonic => mnemonic.isNotEmpty;

  /// 是否持有可簽章 / 解密的秘密材料。
  ///
  /// 用於「公開提示」物件：只描述身份而不含任何秘密，鎖屏時也能安全顯示。
  bool get hasSecrets => ethPrivateHex.isNotEmpty && encSeedHex.isNotEmpty;

  /// 完整序列化（**含助記詞與私鑰**）。
  ///
  /// 這份 JSON 只允許寫進經過 [Vault] 加密的密文裡，絕不可明文落地。
  Map<String, dynamic> toSecretJson() => toJson();

  /// 公開提示：僅含對外可見、本來就會發布到網路的資訊。
  ///
  /// 用途是在「尚未解鎖」的狀態下判斷身份是否存在、顯示帳戶地址、
  /// 以及決定路由。這些欄位即使被讀走也不構成洩漏 ——
  /// `did` 與 `address` 本來就是公開識別碼，`encPublicKeyB64` 也會廣播給聯絡人。
  Map<String, dynamic> toHintJson() => <String, dynamic>{
        'did': did,
        'address': address,
        'tronAddress': tronAddress,
        'encPublicKeyB64': encPublicKeyB64,
        'hasMnemonic': hasMnemonic,
        'createdAt': createdAt.toIso8601String(),
      };

  /// 由密文解出的完整資料還原身份。
  static AppIdentity fromSecretJson(Map<String, dynamic> json) =>
      fromJson(json);
}

import 'dart:convert';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:meta/meta.dart' show immutable;
import 'package:web3dart/credentials.dart' show EthPrivateKey;
import 'package:web3dart/crypto.dart' as eth;

import '../../core/utils/hex.dart';
import 'app_identity.dart';

/// 一段加密后的内容：密文 + MAC + nonce + 一次性公钥。
@immutable
class EncryptedBlob {
  const EncryptedBlob({
    required this.cipherText,
    required this.mac,
    required this.nonce,
    required this.ephemeralPublicKey,
  });

  /// Base64 密文。
  final String cipherText;

  /// Base64 的 GCM 验证标签。
  final String mac;

  /// Base64 的 12 位元组 nonce。
  final String nonce;

  /// Base64 的一次性 X25519 公钥。
  final String ephemeralPublicKey;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'ct': cipherText,
        'mac': mac,
        'nonce': nonce,
        'eph': ephemeralPublicKey,
      };

  static EncryptedBlob? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final ct = raw['ct'];
    final macValue = raw['mac'];
    final nonce = raw['nonce'];
    final eph = raw['eph'];
    if (ct is! String ||
        macValue is! String ||
        nonce is! String ||
        eph is! String) {
      return null;
    }
    return EncryptedBlob(
      cipherText: ct,
      mac: macValue,
      nonce: nonce,
      ephemeralPublicKey: eph,
    );
  }
}

/// 讯息层的密码学服务：
/// - 加密：X25519（一次性金钥 ↔ 对方静态金钥）→ HKDF-SHA256 → AES-256-GCM
/// - 签章：secp256k1（以太坊帐户），可回推签章者地址以验证 DID
class CryptoService {
  CryptoService._(this.identity, this._encKeyPair, this._ethKey);

  final AppIdentity identity;

  final SimpleKeyPair _encKeyPair;
  final EthPrivateKey _ethKey;

  static final X25519 _x25519 = X25519();
  static final AesGcm _aesGcm = AesGcm.with256bits();
  static final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  static final Random _random = Random.secure();

  static Future<CryptoService> create(AppIdentity identity) async {
    final encKeyPair =
        await _x25519.newKeyPairFromSeed(Hex.decode(identity.encSeedHex));
    final ethKey = EthPrivateKey(Hex.decode(identity.ethPrivateHex));
    return CryptoService._(identity, encKeyPair, ethKey);
  }

  // ------------------------------------------------------------------ 加密

  /// 加密给指定公钥（Base64 X25519）。采用一次性金钥提供前向保密。
  Future<EncryptedBlob> seal(
    String plaintext,
    String recipientPublicKeyB64, {
    List<int> aad = const <int>[],
  }) async {
    final ephemeral = await _x25519.newKeyPair();
    final remotePublicKey = SimplePublicKey(
      B64.decode(recipientPublicKeyB64),
      type: KeyPairType.x25519,
    );
    final shared = await _x25519.sharedSecretKey(
      keyPair: ephemeral,
      remotePublicKey: remotePublicKey,
    );
    final key = await _deriveKey(shared);
    final nonce = _randomNonce();
    final box = await _aesGcm.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: nonce,
      aad: aad,
    );
    final ephPublic = await ephemeral.extractPublicKey();
    return EncryptedBlob(
      cipherText: B64.encode(box.cipherText),
      mac: B64.encode(box.mac.bytes),
      nonce: B64.encode(nonce),
      ephemeralPublicKey: B64.encode(ephPublic.bytes),
    );
  }

  /// 加密一份给自己的副本，让多装置从 Waku store 还原历史讯息。
  Future<EncryptedBlob> sealSelf(
    String plaintext, {
    List<int> aad = const <int>[],
  }) {
    return seal(plaintext, identity.encPublicKeyB64, aad: aad);
  }

  /// 解密一段内容。
  Future<String?> open(
    EncryptedBlob blob, {
    List<int> aad = const <int>[],
  }) async {
    try {
      final remotePublicKey = SimplePublicKey(
        B64.decode(blob.ephemeralPublicKey),
        type: KeyPairType.x25519,
      );
      final shared = await _x25519.sharedSecretKey(
        keyPair: _encKeyPair,
        remotePublicKey: remotePublicKey,
      );
      final key = await _deriveKey(shared);
      final clear = await _aesGcm.decrypt(
        SecretBox(
          B64.decode(blob.cipherText),
          nonce: B64.decode(blob.nonce),
          mac: Mac(B64.decode(blob.mac)),
        ),
        secretKey: key,
        aad: aad,
      );
      return utf8.decode(clear);
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------------ 对称加密（群组）

  /// 产生一组新的群组对称金钥（32 位元组）。
  static Uint8List newSymmetricKey() {
    final bytes = Uint8List(32);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  /// 用原始对称金钥加密（群组讯息）。[key] 为 32 位元组。
  Future<EncryptedBlob> sealSymmetric(
    String plaintext,
    List<int> key, {
    List<int> aad = const <int>[],
  }) async {
    final nonce = _randomNonce();
    final box = await _aesGcm.encrypt(
      utf8.encode(plaintext),
      secretKey: SecretKey(key),
      nonce: nonce,
      aad: aad,
    );
    return EncryptedBlob(
      cipherText: B64.encode(box.cipherText),
      mac: B64.encode(box.mac.bytes),
      nonce: B64.encode(nonce),
      // 对称加密无需一次性金钥，留空以与 ECDH 封包区分。
      ephemeralPublicKey: '',
    );
  }

  /// 用原始对称金钥解密（群组讯息）。失败回传 null。
  Future<String?> openSymmetric(
    EncryptedBlob blob,
    List<int> key, {
    List<int> aad = const <int>[],
  }) async {
    try {
      final clear = await _aesGcm.decrypt(
        SecretBox(
          B64.decode(blob.cipherText),
          nonce: B64.decode(blob.nonce),
          mac: Mac(B64.decode(blob.mac)),
        ),
        secretKey: SecretKey(key),
        aad: aad,
      );
      return utf8.decode(clear);
    } catch (_) {
      return null;
    }
  }

  Future<SecretKey> _deriveKey(SecretKey shared) async {
    return _hkdf.deriveKey(
      secretKey: shared,
      nonce: utf8.encode('nexuschat/hkdf/v1'),
      info: utf8.encode('x25519-aes-gcm'),
    );
  }

  static Uint8List _randomNonce() {
    final bytes = Uint8List(12);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  // ------------------------------------------------------------------ 签章

  /// 以以太坊金钥签章，回传 `r:s:v`（16 进位）。
  String signHex(String payload) {
    final hash = eth.keccak256(utf8.encode(payload));
    final sig = eth.sign(hash, _ethKey.privateKey);
    return '${sig.r.toRadixString(16)}:${sig.s.toRadixString(16)}:${sig.v.toRadixString(16)}';
  }

  /// 由签章回推签章者地址（小写 0x），失败回传 null。
  static String? recoverAddress(String payload, String signatureHex) {
    try {
      final parts = signatureHex.split(':');
      if (parts.length != 3) return null;
      final r = BigInt.tryParse(parts[0], radix: 16);
      final s = BigInt.tryParse(parts[1], radix: 16);
      final v = int.tryParse(parts[2], radix: 16);
      if (r == null || s == null || v == null) return null;
      final hash = eth.keccak256(utf8.encode(payload));
      final publicKey = eth.ecRecover(hash, eth.MsgSignature(r, s, v));
      return '0x${Hex.encode(eth.publicKeyToAddress(publicKey))}';
    } catch (_) {
      return null;
    }
  }

  /// 验证签章是否由某个 DID 的持有者发出。
  static bool verifyDid(String did, String payload, String signatureHex) {
    final address = recoverAddress(payload, signatureHex);
    if (address == null) return false;
    final expected = did.toLowerCase().split(':').last.trim();
    return address.toLowerCase() == expected;
  }
}

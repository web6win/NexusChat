import 'dart:convert';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:meta/meta.dart' show immutable;
import 'package:web3dart/credentials.dart' show EthPrivateKey;
import 'package:web3dart/crypto.dart' as eth;

import '../../core/utils/hex.dart';
import 'app_identity.dart';

/// 一段加密後的內容：密文 + MAC + nonce + 一次性公鑰。
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

  /// Base64 的 GCM 驗證標籤。
  final String mac;

  /// Base64 的 12 位元組 nonce。
  final String nonce;

  /// Base64 的一次性 X25519 公鑰。
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

/// 訊息層的密碼學服務：
/// - 加密：X25519（一次性金鑰 ↔ 對方靜態金鑰）→ HKDF-SHA256 → AES-256-GCM
/// - 簽章：secp256k1（以太坊帳戶），可回推簽章者地址以驗證 DID
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

  /// 加密給指定公鑰（Base64 X25519）。採用一次性金鑰提供前向保密。
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

  /// 加密一份給自己的副本，讓多裝置從 Waku store 還原歷史訊息。
  Future<EncryptedBlob> sealSelf(
    String plaintext, {
    List<int> aad = const <int>[],
  }) {
    return seal(plaintext, identity.encPublicKeyB64, aad: aad);
  }

  /// 解密一段內容。
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

  // ------------------------------------------------------------------ 簽章

  /// 以以太坊金鑰簽章，回傳 `r:s:v`（16 進位）。
  String signHex(String payload) {
    final hash = eth.keccak256(utf8.encode(payload));
    final sig = eth.sign(hash, _ethKey.privateKey);
    return '${sig.r.toRadixString(16)}:${sig.s.toRadixString(16)}:${sig.v.toRadixString(16)}';
  }

  /// 由簽章回推簽章者地址（小寫 0x），失敗回傳 null。
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

  /// 驗證簽章是否由某個 DID 的持有者發出。
  static bool verifyDid(String did, String payload, String signatureHex) {
    final address = recoverAddress(payload, signatureHex);
    if (address == null) return false;
    final expected = did.toLowerCase().split(':').last.trim();
    return address.toLowerCase() == expected;
  }
}

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// 保险库例外。[code] 为稳定错误码，供 UI 对照文案。
///
/// - `bad-password`：认证标签不符（密码错误，或密文被窜改）。
/// - `corrupt`：密文结构毁损或无法解析。
/// - `unsupported`：版本或 KDF 不认识（未来升级用）。
class VaultException implements Exception {
  const VaultException(this.code);

  final String code;

  @override
  String toString() => 'VaultException($code)';
}

/// 以使用者密码加密敏感资料（助记词 / 私钥）的本地保险库。
///
/// 设计：
/// - **KDF**：PBKDF2-HMAC-SHA256，预设 21 万次迭代，每份密文独立 salt。
/// - **加密**：AES-256-GCM，16 位元组认证标签。密码错、密文被改、标头被换，
///   都会在解密时被侦测到 —— 不存在「解出垃圾明文」的情况。
/// - **标头公开**：版本、迭代次数、salt、nonce 以明文存放（它们不是秘密），
///   其余一概不落地。
///
/// 为什么是「密码 + KDF」而不是装置绑定金钥：
/// Web 端（IndexedDB）没有任何可信任的硬体金钥储存。凡是「应用能自动解开」
/// 的方案，攻击者只要能执行脚本，就能用同一条路径解开。唯一能真正提高门槛的，
/// 是「只有人知道」的秘密 —— 因此密码是这个威胁模型下唯一有效的防线。
class Vault {
  const Vault._();

  /// 密文格式版本。
  static const int version = 1;

  static const String kdfName = 'pbkdf2-hmac-sha256';

  /// 预设迭代次数。
  ///
  /// OWASP 对 PBKDF2-HMAC-SHA256 的建议是 60 万次。这里取 21 万是为了让
  /// 原生（纯 Dart 实作，无 WebCrypto 加速）的首次解锁仍在一秒内完成。
  /// 迭代次数会写进密文标头，未来可在不破坏旧资料的前提下调高。
  static const int defaultIterations = 210000;

  /// 新增密码时可选的迭代强度。
  static const List<int> supportedIterations = <int>[210000, 600000];

  static const int _saltBytes = 32;
  static const int _nonceBytes = 12;
  static const int _keyBytes = 32;

  /// 附加认证资料：把密文绑定到「NexusChat 的 v1 保险库」这个情境，
  /// 避免同一把金钥加密的其他内容被移花接木过来。
  static final List<int> _aad = utf8.encode('nexuschat/vault/v1');

  static final AesGcm _aead = AesGcm.with256bits();
  static final Random _random = Random.secure();

  /// 判断一包资料是否为本保险库的密文。
  static bool looksLikeVault(Object? raw) {
    if (raw is! Map) return false;
    return raw['kdf'] == kdfName &&
        raw['salt'] is String &&
        raw['nonce'] is String &&
        raw['ct'] is String &&
        raw['mac'] is String;
  }

  /// 读出密文标头记录的迭代次数（供 UI 显示；失败回传预设值）。
  static int iterationsOf(Object? raw) {
    if (raw is! Map) return defaultIterations;
    final value = raw['iterations'];
    return value is int && value > 0 ? value : defaultIterations;
  }

  /// 以 [password] 加密 [payload]，回传可直接写入本地储存的密文 Map。
  static Future<Map<String, dynamic>> seal({
    required Map<String, dynamic> payload,
    required String password,
    int iterations = defaultIterations,
  }) async {
    final salt = _randomBytes(_saltBytes);
    final nonce = _randomBytes(_nonceBytes);
    final secretKey = await _deriveKey(password, salt, iterations);
    final box = await _aead.encrypt(
      utf8.encode(jsonEncode(payload)),
      secretKey: secretKey,
      nonce: nonce,
      aad: _aad,
    );
    return <String, dynamic>{
      'v': version,
      'kdf': kdfName,
      'iterations': iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'ct': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    };
  }

  /// 以 [password] 解密 [blob]，失败时抛出 [VaultException]。
  static Future<Map<String, dynamic>> open({
    required Object? blob,
    required String password,
    int iterations = defaultIterations,
  }) async {
    final parsed = _parse(blob, fallbackIterations: iterations);
    final secretKey =
        await _deriveKey(password, parsed.salt, parsed.iterations);

    List<int> clear;
    try {
      clear = await _aead.decrypt(
        SecretBox(
          parsed.cipherText,
          nonce: parsed.nonce,
          mac: Mac(parsed.mac),
        ),
        secretKey: secretKey,
        aad: _aad,
      );
    } catch (_) {
      // GCM 认证失败 = 密码错误或密文被动过。不对外区分，避免成为猜测 oracle。
      throw const VaultException('bad-password');
    }

    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(clear));
    } catch (_) {
      throw const VaultException('corrupt');
    }
    if (decoded is! Map) throw const VaultException('corrupt');
    return decoded.map((Object? k, Object? v) => MapEntry('$k', v));
  }

  /// 验证密码是否正确（不改动任何状态）。
  static Future<bool> verify({
    required Object? blob,
    required String password,
  }) async {
    try {
      await open(blob: blob, password: password);
      return true;
    } on VaultException {
      return false;
    }
  }

  // ------------------------------------------------------------------ 内部

  static Future<SecretKey> _deriveKey(
    String password,
    List<int> salt,
    int iterations,
  ) {
    // 迭代次数必须来自密文标头，才能在未来提高强度而不破坏旧资料。
    final safeIterations =
        iterations < 1 ? defaultIterations : iterations;
    final kdf = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: safeIterations,
      bits: _keyBytes * 8,
    );
    return kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  static _ParsedVault _parse(Object? blob, {required int fallbackIterations}) {
    if (blob is! Map) throw const VaultException('corrupt');
    if (blob['v'] != version) throw const VaultException('unsupported');
    if (blob['kdf'] != kdfName) throw const VaultException('unsupported');

    final salt = _decode(blob['salt']);
    final nonce = _decode(blob['nonce']);
    final cipherText = _decode(blob['ct']);
    final mac = _decode(blob['mac']);
    if (salt == null || nonce == null || cipherText == null || mac == null) {
      throw const VaultException('corrupt');
    }
    if (salt.isEmpty || nonce.isEmpty || cipherText.isEmpty || mac.isEmpty) {
      throw const VaultException('corrupt');
    }

    final rawIterations = blob['iterations'];
    final iterations = rawIterations is int && rawIterations > 0
        ? rawIterations
        : fallbackIterations;

    return _ParsedVault(
      salt: salt,
      nonce: nonce,
      cipherText: cipherText,
      mac: mac,
      iterations: iterations,
    );
  }

  static Uint8List? _decode(Object? value) {
    if (value is! String) return null;
    try {
      return base64Decode(value);
    } catch (_) {
      return null;
    }
  }

  static Uint8List _randomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }
}

class _ParsedVault {
  const _ParsedVault({
    required this.salt,
    required this.nonce,
    required this.cipherText,
    required this.mac,
    required this.iterations,
  });

  final Uint8List salt;
  final Uint8List nonce;
  final Uint8List cipherText;
  final Uint8List mac;
  final int iterations;
}

/// 密码强度评估结果。
class PasswordStrength {
  const PasswordStrength({
    required this.score,
    required this.label,
  });

  /// 0（最弱）～ 4（最强）。
  final int score;

  /// 稳定标签码，供 i18n 对照：`weak` / `fair` / `good` / `strong`。
  final String label;

  bool get isAcceptable => score >= 2;
}

/// 密码强度检查。
///
/// 这里刻意「拒绝太弱」而不是只给提示：保险库的安全性完全建立在密码上，
/// 一个四位数字密码会让 21 万次迭代的 KDF 形同虚设。
class PasswordPolicy {
  const PasswordPolicy._();

  static const int minLength = 8;

  static PasswordStrength evaluate(String password) {
    if (password.isEmpty) {
      return const PasswordStrength(score: 0, label: 'weak');
    }
    var variety = 0;
    if (RegExp(r'[a-z]').hasMatch(password)) variety++;
    if (RegExp(r'[A-Z]').hasMatch(password)) variety++;
    if (RegExp(r'[0-9]').hasMatch(password)) variety++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) variety++;

    var score = 0;
    if (password.length >= minLength) score++;
    if (password.length >= 12) score++;
    if (variety >= 2) score++;
    if (variety >= 3) score++;

    // 常见弱密码、或纯数字密码，直接压到最低。
    if (_isCommon(password) || _isAllDigits(password)) score = 0;

    final label = switch (score) {
      >= 4 => 'strong',
      3 => 'good',
      2 => 'fair',
      _ => 'weak',
    };
    return PasswordStrength(score: score, label: label);
  }

  static const Set<String> _common = <String>{
    'password',
    'password1',
    'password123',
    '12345678',
    '123456789',
    '1234567890',
    'qwertyui',
    'qwerty123',
    'iloveyou',
    'admin123',
    'abc12345',
    '11111111',
    '00000000',
    'nexuschat',
    'nexuschat123',
    'letmein1',
    'welcome1',
    'monkey123',
  };

  static bool _isCommon(String password) {
    final lower = password.toLowerCase();
    if (_common.contains(lower)) return true;
    // 单一字元重复（aaaaaaaa）或连续数字（12345678901）。
    if (RegExp(r'^(.)\1+$').hasMatch(lower)) return true;
    if (RegExp(r'^(0123456789|1234567890)+$').hasMatch(lower)) return true;
    return false;
  }

  /// 纯数字密码。
  ///
  /// 即使长度足够，搜寻空间仍远小于同长度的混合密码；而且使用者的「数字密码」
  /// 几乎都落在生日、电话、连续序列这些高机率样式上。一律拒绝。
  static bool _isAllDigits(String password) =>
      RegExp(r'^[0-9]+$').hasMatch(password);
}

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// 保險庫例外。[code] 為穩定錯誤碼，供 UI 對照文案。
///
/// - `bad-password`：認證標籤不符（密碼錯誤，或密文被竄改）。
/// - `corrupt`：密文結構毀損或無法解析。
/// - `unsupported`：版本或 KDF 不認識（未來升級用）。
class VaultException implements Exception {
  const VaultException(this.code);

  final String code;

  @override
  String toString() => 'VaultException($code)';
}

/// 以使用者密碼加密敏感資料（助記詞 / 私鑰）的本地保險庫。
///
/// 設計：
/// - **KDF**：PBKDF2-HMAC-SHA256，預設 21 萬次迭代，每份密文獨立 salt。
/// - **加密**：AES-256-GCM，16 位元組認證標籤。密碼錯、密文被改、標頭被換，
///   都會在解密時被偵測到 —— 不存在「解出垃圾明文」的情況。
/// - **標頭公開**：版本、迭代次數、salt、nonce 以明文存放（它們不是秘密），
///   其餘一概不落地。
///
/// 為什麼是「密碼 + KDF」而不是裝置綁定金鑰：
/// Web 端（IndexedDB）沒有任何可信任的硬體金鑰儲存。凡是「應用能自動解開」
/// 的方案，攻擊者只要能執行腳本，就能用同一條路徑解開。唯一能真正提高門檻的，
/// 是「只有人知道」的秘密 —— 因此密碼是這個威脅模型下唯一有效的防線。
class Vault {
  const Vault._();

  /// 密文格式版本。
  static const int version = 1;

  static const String kdfName = 'pbkdf2-hmac-sha256';

  /// 預設迭代次數。
  ///
  /// OWASP 對 PBKDF2-HMAC-SHA256 的建議是 60 萬次。這裡取 21 萬是為了讓
  /// 原生（純 Dart 實作，無 WebCrypto 加速）的首次解鎖仍在一秒內完成。
  /// 迭代次數會寫進密文標頭，未來可在不破壞舊資料的前提下調高。
  static const int defaultIterations = 210000;

  /// 新增密碼時可選的迭代強度。
  static const List<int> supportedIterations = <int>[210000, 600000];

  static const int _saltBytes = 32;
  static const int _nonceBytes = 12;
  static const int _keyBytes = 32;

  /// 附加認證資料：把密文綁定到「NexusChat 的 v1 保險庫」這個情境，
  /// 避免同一把金鑰加密的其他內容被移花接木過來。
  static final List<int> _aad = utf8.encode('nexuschat/vault/v1');

  static final AesGcm _aead = AesGcm.with256bits();
  static final Random _random = Random.secure();

  /// 判斷一包資料是否為本保險庫的密文。
  static bool looksLikeVault(Object? raw) {
    if (raw is! Map) return false;
    return raw['kdf'] == kdfName &&
        raw['salt'] is String &&
        raw['nonce'] is String &&
        raw['ct'] is String &&
        raw['mac'] is String;
  }

  /// 讀出密文標頭記錄的迭代次數（供 UI 顯示；失敗回傳預設值）。
  static int iterationsOf(Object? raw) {
    if (raw is! Map) return defaultIterations;
    final value = raw['iterations'];
    return value is int && value > 0 ? value : defaultIterations;
  }

  /// 以 [password] 加密 [payload]，回傳可直接寫入本地儲存的密文 Map。
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

  /// 以 [password] 解密 [blob]，失敗時拋出 [VaultException]。
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
      // GCM 認證失敗 = 密碼錯誤或密文被動過。不對外區分，避免成為猜測 oracle。
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

  /// 驗證密碼是否正確（不改動任何狀態）。
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

  // ------------------------------------------------------------------ 內部

  static Future<SecretKey> _deriveKey(
    String password,
    List<int> salt,
    int iterations,
  ) {
    // 迭代次數必須來自密文標頭，才能在未來提高強度而不破壞舊資料。
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

/// 密碼強度評估結果。
class PasswordStrength {
  const PasswordStrength({
    required this.score,
    required this.label,
  });

  /// 0（最弱）～ 4（最強）。
  final int score;

  /// 穩定標籤碼，供 i18n 對照：`weak` / `fair` / `good` / `strong`。
  final String label;

  bool get isAcceptable => score >= 2;
}

/// 密碼強度檢查。
///
/// 這裡刻意「拒絕太弱」而不是只給提示：保險庫的安全性完全建立在密碼上，
/// 一個四位數字密碼會讓 21 萬次迭代的 KDF 形同虛設。
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

    // 常見弱密碼、或純數字密碼，直接壓到最低。
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
    // 單一字元重複（aaaaaaaa）或連續數字（12345678901）。
    if (RegExp(r'^(.)\1+$').hasMatch(lower)) return true;
    if (RegExp(r'^(0123456789|1234567890)+$').hasMatch(lower)) return true;
    return false;
  }

  /// 純數字密碼。
  ///
  /// 即使長度足夠，搜尋空間仍遠小於同長度的混合密碼；而且使用者的「數字密碼」
  /// 幾乎都落在生日、電話、連續序列這些高機率樣式上。一律拒絕。
  static bool _isAllDigits(String password) =>
      RegExp(r'^[0-9]+$').hasMatch(password);
}

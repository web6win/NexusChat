import 'dart:convert';
import 'dart:typed_data';

/// 十六進位與 Base64 的輕量工具，避免對外部套件格式細節的依賴。
abstract final class Hex {
  static const _digits = '0123456789abcdef';

  /// 位元組 → 十六進位字串。
  static String encode(List<int> bytes, {bool include0x = false}) {
    final buffer = StringBuffer();
    if (include0x) buffer.write('0x');
    for (final b in bytes) {
      buffer.write(_digits[(b >> 4) & 0x0F]);
      buffer.write(_digits[b & 0x0F]);
    }
    return buffer.toString();
  }

  /// 十六進位字串 → 位元組（容許 0x 前綴與奇數長度）。
  static Uint8List decode(String hex) {
    var s = hex.trim().toLowerCase();
    if (s.startsWith('0x')) s = s.substring(2);
    if (s.length % 2 == 1) s = '0$s';
    final out = Uint8List(s.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }
}

/// Base64 工具（URL 安全不啟用，與 Waku payload 慣例一致）。
abstract final class B64 {
  static String encode(List<int> bytes) => base64Encode(bytes);

  static Uint8List decode(String value) => base64Decode(value);
}

import 'dart:convert';
import 'dart:typed_data';

/// 十六进位与 Base64 的轻量工具，避免对外部套件格式细节的依赖。
abstract final class Hex {
  static const _digits = '0123456789abcdef';

  /// 位元组 → 十六进位字串。
  static String encode(List<int> bytes, {bool include0x = false}) {
    final buffer = StringBuffer();
    if (include0x) buffer.write('0x');
    for (final b in bytes) {
      buffer.write(_digits[(b >> 4) & 0x0F]);
      buffer.write(_digits[b & 0x0F]);
    }
    return buffer.toString();
  }

  /// 十六进位字串 → 位元组（容许 0x 前缀与奇数长度）。
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

/// Base64 工具（URL 安全不启用，与 Waku payload 惯例一致）。
abstract final class B64 {
  static String encode(List<int> bytes) => base64Encode(bytes);

  static Uint8List decode(String value) => base64Decode(value);
}

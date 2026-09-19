import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:web3dart/crypto.dart' show keccak256;

import '../../core/utils/hex.dart';

/// TRON 地址（Base58Check）編解碼。
///
/// TRON 主網地址 = `Base58Check(0x41 ‖ keccak256(公鑰)[12:32])`，
/// 其中 `keccak256(公鑰)[12:32]` 恰好就是以太坊地址的那 20 個位元組。
/// 因此同一把 secp256k1 公鑰會同時對應一個 0x 以太坊地址與一個 T 開頭的
/// TRON 地址——兩者是同一個帳戶的兩種編碼。
abstract final class TronAddress {
  /// 主網版本位元組。
  static const int _version = 0x41;

  /// 由未壓縮公鑰（64 位元組 hex，不含 0x04 前綴）推導 TRON 地址。
  static String fromPublicKeyHex(String uncompressedPublicKeyHex) {
    final pub = _decodeHex(uncompressedPublicKeyHex);
    final hash = keccak256(pub);
    // keccak256 輸出 32 位元組，取末 20 位元組作為地址主體。
    final addressBytes = hash.sublist(12, 32);
    final payload = Uint8List(21)..[0] = _version;
    payload.setRange(1, 21, addressBytes);
    final checksum = _checksum(payload);
    final full = Uint8List(25)
      ..setRange(0, 21, payload)
      ..setRange(21, 25, checksum);
    return _base58Encode(full);
  }

  /// 是否為合法的 TRON 主網地址（T 開頭、25 位元組、校驗和通過）。
  static bool isValid(String address) {
    if (address.length != 34 || !address.startsWith('T')) return false;
    final bytes = _base58Decode(address);
    if (bytes == null || bytes.length != 25) return false;
    if (bytes[0] != _version) return false;
    final payload = bytes.sublist(0, 21);
    final checksum = bytes.sublist(21, 25);
    final expected = _checksum(payload);
    for (var i = 0; i < 4; i++) {
      if (checksum[i] != expected[i]) return false;
    }
    return true;
  }

  /// 把 Base58Check 地址轉成節點 API 用的 41 開頭 hex（不含 0x）。
  ///
  /// TRON 的 `/wallet/createtransaction` 需要 `41...` 格式的地址，
  /// 而非 T 開頭的顯示形式。非法地址時回傳原字串。
  static String toHex(String address) {
    final bytes = _base58Decode(address);
    if (bytes == null || bytes.length != 25) return address;
    return Hex.encode(bytes.sublist(0, 21));
  }

  static Uint8List _checksum(Uint8List payload) {
    final first = sha256.convert(payload).bytes;
    final second = sha256.convert(first).bytes;
    return Uint8List.fromList(second.sublist(0, 4));
  }

  static Uint8List _decodeHex(String hex) {
    var s = hex.trim();
    if (s.startsWith('0x')) s = s.substring(2);
    if (s.length.isOdd) s = '0$s';
    final result = Uint8List(s.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  /// Base58 編碼（不含前綴字元）。
  static String _base58Encode(Uint8List input) {
    const alphabet =
        '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    var num = BigInt.parse(
      input.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      radix: 16,
    );
    final result = StringBuffer();
    while (num > BigInt.zero) {
      final remainder = num % BigInt.from(58);
      num ~/= BigInt.from(58);
      result.write(alphabet[remainder.toInt()]);
    }
    // 還原前導零（0x00）為 '1'。
    for (var i = 0; i < input.length && input[i] == 0; i++) {
      result.write('1');
    }
    return result.toString().split('').reversed.join();
  }

  static Uint8List? _base58Decode(String input) {
    const alphabet =
        '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    final map = <int, int>{};
    for (var i = 0; i < alphabet.length; i++) {
      map[alphabet.codeUnitAt(i)] = i;
    }
    var num = BigInt.zero;
    for (final rune in input.runes) {
      final value = map[rune];
      if (value == null) return null;
      num = num * BigInt.from(58) + BigInt.from(value);
    }
    var hex = num.toRadixString(16);
    if (hex.length.isOdd) hex = '0$hex';
    var bytes = _decodeHex(hex);
    // 補足 25 位元組，並還原前導 '1' 對應的 0x00。
    final leadingOnes =
        input.runes.takeWhile((r) => r == '1'.runes.first).length;
    if (leadingOnes > 0) {
      bytes = Uint8List.fromList(<int>[
        ...List<int>.filled(leadingOnes, 0),
        ...bytes,
      ]);
    }
    // 去掉多餘的高位 0x00（Base58 解碼可能多補）。
    while (bytes.length > 25 && bytes[0] == 0) {
      bytes = bytes.sublist(1);
    }
    return bytes.length == 25 ? bytes : null;
  }
}

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:web3dart/credentials.dart' show EthPrivateKey;
import 'package:web3dart/crypto.dart' show privateKeyToPublic, keccak256;

import 'package:nexuschat/data/crypto/tron_address.dart';

/// TRON 地址派生验证：
/// 同一把 secp256k1 私钥的 TRON 地址主体（20 位元组）必须与以太坊地址完全一致，
/// 因为两者都是 keccak256(公钥)[12:32]。这同时验证 Base58Check 编解码与校验和。
void main() {
  test('tron address body equals ethereum address bytes', () {
    // 固定私钥，确保可重现。
    final priv = EthPrivateKey.fromHex(
      '0x4c0883a4912c8a5d3b9d6f7e1a2b3c4d5e6f70819a2b3c4d5e6f70819a2b3c4d',
    );
    final ethAddress = '0x${priv.address.hexNo0x}';
    final pubHex = privateKeyToPublic(priv.privateKeyInt).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    final tron = TronAddress.fromPublicKeyHex(pubHex);

    // 1) 格式正确：T 开头、34 字元。
    expect(tron.startsWith('T'), isTrue);
    expect(tron.length, 34);

    // 2) 校验和通过。
    expect(TronAddress.isValid(tron), isTrue);

    // 3) 解码后主体必须等于以太坊地址的 20 位元组。
    final decoded = _decodeKnownGood(tron);
    final tronBody = decoded.sublist(1, 21);
    final ethBytes = keccak256(Uint8List.fromList(_hexToBytes(pubHex))).sublist(12, 32);
    expect(tronBody, equals(ethBytes));
    expect(tronBody, equals(_hexToBytes(ethAddress)));

    // 4) 版本位元组为 0x41（TRON 主网）。
    expect(decoded[0], 0x41);
  });

  test('invalid tron address rejected', () {
    expect(TronAddress.isValid('0x1234567890abcdef'), isFalse);
    expect(TronAddress.isValid('TInvalidChecksum1234567890abcdefghij'), isFalse);
    expect(TronAddress.isValid(''), isFalse);
  });
}

Uint8List _hexToBytes(String hex) {
  var s = hex.trim();
  if (s.startsWith('0x')) s = s.substring(2);
  final out = Uint8List(s.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

/// 复制 TronAddress 的解码逻辑做独立验证（避免直接依赖私有方法）。
Uint8List _decodeKnownGood(String address) {
  const alphabet =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  final map = <int, int>{};
  for (var i = 0; i < alphabet.length; i++) {
    map[alphabet.codeUnitAt(i)] = i;
  }
  var num = BigInt.zero;
  for (final rune in address.runes) {
    num = num * BigInt.from(58) + BigInt.from(map[rune]!);
  }
  var hex = num.toRadixString(16);
  if (hex.length.isOdd) hex = '0$hex';
  final bytes = _hexToBytes(hex);
  final leading = address.runes.takeWhile((r) => r == '1'.runes.first).length;
  final full = Uint8List.fromList(<int>[
    ...List<int>.filled(leading, 0),
    ...bytes,
  ]);
  return full.length == 25 ? full : full.sublist(full.length - 25);
}

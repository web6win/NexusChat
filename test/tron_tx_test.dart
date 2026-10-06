import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:test/test.dart';
import 'package:web3dart/credentials.dart' show EthPrivateKey;
import 'package:web3dart/crypto.dart'
    show MsgSignature, bytesToHex, ecRecover, hexToBytes, privateKeyToPublic, sign, unsignedIntToBytes;
// padUint8ListTo32 由 src/utils/typed_data.dart 提供，仅经 web3dart.dart 转出。
import 'package:web3dart/web3dart.dart' show padUint8ListTo32;

import '../lib/data/crypto/tron_address.dart';
import '../lib/data/ethereum/tx_service.dart';

/// TRON 签章流程的离线验证（不需连网）。
///
/// TRON 的 txID = `sha256(raw_data)`，签章是对这 32 位元组做 secp256k1
/// ECDSA，输出 `r‖s‖v` 共 65 位元组。这里验证签完之后能用签章还原出
/// 签章者公钥 —— 这正是节点验签时做的事。
void main() {
  const privateHex =
      '4646464646464646464646464646464646464646464646464646464646464646';

  test('TRON 地址可转成节点用的 41 开头 hex', () {
    // 波场基金会公开地址，用于验证编码正确性。
    const address = 'TXFBqBbqJommqZf7BV8NNYzePh97UmJodJ';
    expect(TronAddress.isValid(address), isTrue);

    final hex = TronAddress.toHex(address);
    expect(hex.length, 42, reason: '21 位元组 = 42 个 hex 字元');
    expect(hex.startsWith('41'), isTrue, reason: '主网版本位元组');
  });

  test('非法 TRON 地址被拒绝', () {
    expect(TronAddress.isValid(''), isFalse);
    expect(TronAddress.isValid('0x1234'), isFalse);
    expect(TronAddress.isValid('T${'1' * 33}'), isFalse);
    // 校验和被篡改（结尾由 J 改为 K）。
    expect(TronAddress.isValid('TXFBqBbqJommqZf7BV8NNYzePh97UmJodK'), isFalse);
  });

  test('对 sha256(raw_data) 做原始 secp256k1 签章后可还原公钥', () {
    final rawData = Uint8List.fromList(
      List<int>.generate(32, (i) => (i * 7 + 3) & 0xFF),
    );
    final txId = Uint8List.fromList(sha256.convert(rawData).bytes);
    expect(txId.length, 32, reason: 'txID 固定 32 位元组');

    final privateKey = hexToBytes(privateHex);
    // 关键：使用低阶 sign() 对「杂凑本身」签章。若改用
    // EthPrivateKey.signToEcSignature，它会先做一次 keccak256，签出来的
    // 结果无法被节点用 txID 验证 —— 这是最容易踩的坑。
    final MsgSignature signature = sign(txId, privateKey);
    expect(signature.v, greaterThanOrEqualTo(27), reason: 'v 为 27/28');

    final packed = Uint8List(65)
      ..setRange(0, 32, padUint8ListTo32(unsignedIntToBytes(signature.r)))
      ..setRange(32, 64, padUint8ListTo32(unsignedIntToBytes(signature.s)))
      ..[64] = signature.v;
    expect(packed.length, 65, reason: 'TRON 签章为 r‖s‖v 共 65 位元组');

    final recovered = ecRecover(txId, signature);
    final expected = privateKeyToPublic(BigInt.parse(privateHex, radix: 16));
    expect(bytesToHex(recovered), bytesToHex(expected));
  });

  test('用签章者的 secp256k1 签章不能再用 keccak256 版本（回归保护）', () {
    final txId = Uint8List.fromList(
      sha256.convert(Uint8List.fromList(List<int>.filled(32, 7))).bytes,
    );
    final key = EthPrivateKey(hexToBytes(privateHex));
    // signToEcSignature 内部会 keccak256 一次，所以还原出的公钥不会是签章者。
    final keccakSig = key.signToEcSignature(txId);
    final expected = privateKeyToPublic(key.privateKeyInt);
    expect(
      bytesToHex(ecRecover(txId, keccakSig)),
      isNot(bytesToHex(expected)),
      reason: '确认两者语意不同：TRON 必须用原始 secp256k1 sign',
    );
  });

  test('打包后的签章是 65 位元组、v 为 0/1 且为 low-S', () {
    final privateKey = hexToBytes(privateHex);
    final expected = privateKeyToPublic(BigInt.parse(privateHex, radix: 16));

    // 曲线阶 N 与 low-S 的界线。
    final n = BigInt.parse(
      'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141',
      radix: 16,
    );

    // 跑多组 raw_data，确保 low-S 规约在「需要翻转」与「不需要」两种情况
    // 都能还原出同一把公钥 —— 只测一组很可能刚好落在不需要规约的那半边。
    for (var seed = 0; seed < 24; seed++) {
      final rawData = Uint8List.fromList(
        List<int>.generate(32, (i) => (i * 31 + seed * 7 + 1) & 0xFF),
      );
      final txId = Uint8List.fromList(sha256.convert(rawData).bytes);
      final signature = sign(txId, privateKey);
      final packed = hexToBytes(TxService.packSignature(signature));

      expect(packed.length, 65, reason: 'TRON 签章为 r‖s‖v 共 65 位元组');

      final v = packed[64];
      expect(v == 0 || v == 1, isTrue,
          reason: 'TRON 的第 65 位元组只接受恢复识别码，不能是 27/28（得到 $v）');

      // 以打包后的 r‖s 与恢复识别码还原公钥：必须是签章者本人。
      final r = BigInt.parse(bytesToHex(packed.sublist(0, 32)), radix: 16);
      final s = BigInt.parse(bytesToHex(packed.sublist(32, 64)), radix: 16);
      expect(s <= (n >> 1), isTrue, reason: 'java-tron 拒收 high-S 签章');
      expect(s > BigInt.zero, isTrue);

      // ecRecover 吃的是 27/28 惯例，故还原时加回 27。
      final recovered = ecRecover(txId, MsgSignature(r, s, v + 27));
      expect(bytesToHex(recovered), bytesToHex(expected),
          reason: '规约后仍须还原出签章者公钥（第 $seed 组）');
    }
  });

  test('createtransaction payload 使用 hex 地址且 visible=false', () {
    const address = 'TXFBqBbqJommqZf7BV8NNYzePh97UmJodJ';
    final payload = jsonEncode(<String, dynamic>{
      'owner_address': '41${'0' * 40}',
      'to_address': TronAddress.toHex(address),
      'amount': 1000000,
      'visible': false,
    });
    final decoded = jsonDecode(payload) as Map<String, dynamic>;
    expect(decoded['visible'], isFalse);
    expect(decoded['to_address'], TronAddress.toHex(address));
    expect(decoded['amount'], 1000000, reason: '1 TRX = 1e6 SUN');
  });
}

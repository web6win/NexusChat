import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:test/test.dart';
import 'package:web3dart/credentials.dart' show EthPrivateKey;
import 'package:web3dart/crypto.dart'
    show MsgSignature, bytesToHex, ecRecover, hexToBytes, privateKeyToPublic, sign, unsignedIntToBytes;
// padUint8ListTo32 由 src/utils/typed_data.dart 提供，僅經 web3dart.dart 轉出。
import 'package:web3dart/web3dart.dart' show padUint8ListTo32;

import '../lib/data/crypto/tron_address.dart';
import '../lib/data/ethereum/tx_service.dart';

/// TRON 簽章流程的離線驗證（不需連網）。
///
/// TRON 的 txID = `sha256(raw_data)`，簽章是對這 32 位元組做 secp256k1
/// ECDSA，輸出 `r‖s‖v` 共 65 位元組。這裡驗證簽完之後能用簽章還原出
/// 簽章者公鑰 —— 這正是節點驗簽時做的事。
void main() {
  const privateHex =
      '4646464646464646464646464646464646464646464646464646464646464646';

  test('TRON 地址可轉成節點用的 41 開頭 hex', () {
    // 波場基金會公開地址，用於驗證編碼正確性。
    const address = 'TXFBqBbqJommqZf7BV8NNYzePh97UmJodJ';
    expect(TronAddress.isValid(address), isTrue);

    final hex = TronAddress.toHex(address);
    expect(hex.length, 42, reason: '21 位元組 = 42 個 hex 字元');
    expect(hex.startsWith('41'), isTrue, reason: '主網版本位元組');
  });

  test('非法 TRON 地址被拒絕', () {
    expect(TronAddress.isValid(''), isFalse);
    expect(TronAddress.isValid('0x1234'), isFalse);
    expect(TronAddress.isValid('T${'1' * 33}'), isFalse);
    // 校驗和被篡改（結尾由 J 改為 K）。
    expect(TronAddress.isValid('TXFBqBbqJommqZf7BV8NNYzePh97UmJodK'), isFalse);
  });

  test('對 sha256(raw_data) 做原始 secp256k1 簽章後可還原公鑰', () {
    final rawData = Uint8List.fromList(
      List<int>.generate(32, (i) => (i * 7 + 3) & 0xFF),
    );
    final txId = Uint8List.fromList(sha256.convert(rawData).bytes);
    expect(txId.length, 32, reason: 'txID 固定 32 位元組');

    final privateKey = hexToBytes(privateHex);
    // 關鍵：使用低階 sign() 對「雜湊本身」簽章。若改用
    // EthPrivateKey.signToEcSignature，它會先做一次 keccak256，簽出來的
    // 結果無法被節點用 txID 驗證 —— 這是最容易踩的坑。
    final MsgSignature signature = sign(txId, privateKey);
    expect(signature.v, greaterThanOrEqualTo(27), reason: 'v 為 27/28');

    final packed = Uint8List(65)
      ..setRange(0, 32, padUint8ListTo32(unsignedIntToBytes(signature.r)))
      ..setRange(32, 64, padUint8ListTo32(unsignedIntToBytes(signature.s)))
      ..[64] = signature.v;
    expect(packed.length, 65, reason: 'TRON 簽章為 r‖s‖v 共 65 位元組');

    final recovered = ecRecover(txId, signature);
    final expected = privateKeyToPublic(BigInt.parse(privateHex, radix: 16));
    expect(bytesToHex(recovered), bytesToHex(expected));
  });

  test('用簽章者的 secp256k1 簽章不能再用 keccak256 版本（回歸保護）', () {
    final txId = Uint8List.fromList(
      sha256.convert(Uint8List.fromList(List<int>.filled(32, 7))).bytes,
    );
    final key = EthPrivateKey(hexToBytes(privateHex));
    // signToEcSignature 內部會 keccak256 一次，所以還原出的公鑰不會是簽章者。
    final keccakSig = key.signToEcSignature(txId);
    final expected = privateKeyToPublic(key.privateKeyInt);
    expect(
      bytesToHex(ecRecover(txId, keccakSig)),
      isNot(bytesToHex(expected)),
      reason: '確認兩者語意不同：TRON 必須用原始 secp256k1 sign',
    );
  });

  test('打包後的簽章是 65 位元組、v 為 0/1 且為 low-S', () {
    final privateKey = hexToBytes(privateHex);
    final expected = privateKeyToPublic(BigInt.parse(privateHex, radix: 16));

    // 曲線階 N 與 low-S 的界線。
    final n = BigInt.parse(
      'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141',
      radix: 16,
    );

    // 跑多組 raw_data，確保 low-S 規約在「需要翻轉」與「不需要」兩種情況
    // 都能還原出同一把公鑰 —— 只測一組很可能剛好落在不需要規約的那半邊。
    for (var seed = 0; seed < 24; seed++) {
      final rawData = Uint8List.fromList(
        List<int>.generate(32, (i) => (i * 31 + seed * 7 + 1) & 0xFF),
      );
      final txId = Uint8List.fromList(sha256.convert(rawData).bytes);
      final signature = sign(txId, privateKey);
      final packed = hexToBytes(TxService.packSignature(signature));

      expect(packed.length, 65, reason: 'TRON 簽章為 r‖s‖v 共 65 位元組');

      final v = packed[64];
      expect(v == 0 || v == 1, isTrue,
          reason: 'TRON 的第 65 位元組只接受恢復識別碼，不能是 27/28（得到 $v）');

      // 以打包後的 r‖s 與恢復識別碼還原公鑰：必須是簽章者本人。
      final r = BigInt.parse(bytesToHex(packed.sublist(0, 32)), radix: 16);
      final s = BigInt.parse(bytesToHex(packed.sublist(32, 64)), radix: 16);
      expect(s <= (n >> 1), isTrue, reason: 'java-tron 拒收 high-S 簽章');
      expect(s > BigInt.zero, isTrue);

      // ecRecover 吃的是 27/28 慣例，故還原時加回 27。
      final recovered = ecRecover(txId, MsgSignature(r, s, v + 27));
      expect(bytesToHex(recovered), bytesToHex(expected),
          reason: '規約後仍須還原出簽章者公鑰（第 $seed 組）');
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

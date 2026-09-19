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

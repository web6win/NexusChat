import 'package:test/test.dart';

import '../lib/data/crypto/app_identity.dart';
import '../lib/data/crypto/did.dart';

/// 私鑰匯入的離線驗證（不需連網）。
///
/// 重點在於：格式寬鬆解析（0x 前綴、大小寫、前導零）與邊界檢查（零、超過
/// 曲線階、非 hex），以及推導出的地址必須與已知向量一致。
void main() {
  // 已知向量：私鑰 0x01 對應的以太坊地址（廣泛引用的測試資料）。
  const privateOne =
      '0000000000000000000000000000000000000000000000000000000000000001';
  const addressOne = '0x7e5f4552091a69125d5dfcb7b8c2659029395bdf';

  // 另一組常用測試私鑰。
  const privA =
      '4646464646464646464646464646464646464646464646464646464646464646';

  test('私鑰 0x01 推導出已知地址', () {
    expect(AppIdentity.addressFromPrivateKey(privateOne), addressOne);
  });

  test('匯入私鑰後 address 與 tronAddress 都指向同一帳戶', () async {
    final identity = await AppIdentity.fromPrivateKeyHex(privA);
    expect(identity.address, AppIdentity.addressFromPrivateKey(privA));
    expect(identity.tronAddress.startsWith('T'), isTrue);
    // 私鑰匯入沒有助記詞，UI 據此顯示私鑰備份而非助記詞。
    expect(identity.hasMnemonic, isFalse);
    expect(identity.mnemonic, isEmpty);
  });

  test('接受 0x 前綴、大小寫與空白', () {
    const mixed = '0x4646464646464646464646464646464646464646464646464646464646464646';
    expect(AppIdentity.isValidPrivateKey(mixed), isTrue);
    expect(AppIdentity.addressFromPrivateKey(mixed),
        AppIdentity.addressFromPrivateKey(privA));
    expect(AppIdentity.isValidPrivateKey('  $privA  '), isTrue);
    expect(AppIdentity.isValidPrivateKey('0X$privA'), isTrue);
  });

  test('前導零被截短的私鑰會自動補回 32 位元組', () {
    // 少了 63 個前導零的 "1"，應等價於完整的 0x01 私鑰。
    expect(AppIdentity.isValidPrivateKey('1'), isTrue);
    expect(AppIdentity.addressFromPrivateKey('1'), addressOne);
    expect(AppIdentity.addressFromPrivateKey('0x1'), addressOne);
  });

  test('拒絕零私鑰與超出曲線階的私鑰', () {
    expect(AppIdentity.isValidPrivateKey('0' * 64), isFalse, reason: '零不合法');
    expect(
      AppIdentity.isValidPrivateKey(
        'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
      ),
      isFalse,
      reason: '等於 2^256-1，遠超曲線階 N',
    );
    // N 本身也不合法（必須 < N）。
    expect(
      AppIdentity.isValidPrivateKey(
        'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141',
      ),
      isFalse,
    );
    // N-1 是合法的上界。
    expect(
      AppIdentity.isValidPrivateKey(
        'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140',
      ),
      isTrue,
    );
  });

  test('拒絕長度不足、過長與非十六進位的輸入', () {
    expect(AppIdentity.isValidPrivateKey(''), isFalse);
    expect(AppIdentity.isValidPrivateKey('   '), isFalse);
    // 65 個 hex 字元 → 超過 32 位元組。
    expect(AppIdentity.isValidPrivateKey('1' * 65), isFalse);
    // 含非 hex 字元。
    expect(AppIdentity.isValidPrivateKey('zz' * 32), isFalse);
    expect(AppIdentity.isValidPrivateKey('$privA!'), isFalse);
    // 助記詞不是私鑰。
    expect(AppIdentity.isValidPrivateKey('apple banana cat'), isFalse);
  });

  test('非法私鑰在 fromPrivateKeyHex / addressFromPrivateKey 皆拋出', () async {
    expect(
      () => AppIdentity.addressFromPrivateKey('not-a-key'),
      throwsFormatException,
    );
    await expectLater(
      AppIdentity.fromPrivateKeyHex('not-a-key'),
      throwsFormatException,
    );
  });

  test('同一私鑰重複匯入得到相同 DID 與加密公鑰（決定性）', () async {
    final first = await AppIdentity.fromPrivateKeyHex(privA);
    final second = await AppIdentity.fromPrivateKeyHex(privA);
    expect(first.did, second.did);
    expect(first.encSeedHex, second.encSeedHex);
    expect(first.encPublicKeyB64, second.encPublicKeyB64);
    expect(first.did, Did.fromAddress(first.address));
  });
}

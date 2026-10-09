import 'package:test/test.dart';

import 'package:nexuschat/data/crypto/app_identity.dart';
import 'package:nexuschat/data/crypto/did.dart';

/// 私钥汇入的离线验证（不需连网）。
///
/// 重点在于：格式宽松解析（0x 前缀、大小写、前导零）与边界检查（零、超过
/// 曲线阶、非 hex），以及推导出的地址必须与已知向量一致。
void main() {
  // 已知向量：私钥 0x01 对应的以太坊地址（广泛引用的测试资料）。
  const privateOne =
      '0000000000000000000000000000000000000000000000000000000000000001';
  const addressOne = '0x7e5f4552091a69125d5dfcb7b8c2659029395bdf';

  // 另一组常用测试私钥。
  const privA =
      '4646464646464646464646464646464646464646464646464646464646464646';

  test('私钥 0x01 推导出已知地址', () {
    expect(AppIdentity.addressFromPrivateKey(privateOne), addressOne);
  });

  test('汇入私钥后 address 与 tronAddress 都指向同一帐户', () async {
    final identity = await AppIdentity.fromPrivateKeyHex(privA);
    expect(identity.address, AppIdentity.addressFromPrivateKey(privA));
    expect(identity.tronAddress.startsWith('T'), isTrue);
    // 私钥汇入没有助记词，UI 据此显示私钥备份而非助记词。
    expect(identity.hasMnemonic, isFalse);
    expect(identity.mnemonic, isEmpty);
  });

  test('接受 0x 前缀、大小写与空白', () {
    const mixed = '0x4646464646464646464646464646464646464646464646464646464646464646';
    expect(AppIdentity.isValidPrivateKey(mixed), isTrue);
    expect(AppIdentity.addressFromPrivateKey(mixed),
        AppIdentity.addressFromPrivateKey(privA));
    expect(AppIdentity.isValidPrivateKey('  $privA  '), isTrue);
    expect(AppIdentity.isValidPrivateKey('0X$privA'), isTrue);
  });

  test('前导零被截短的私钥会自动补回 32 位元组', () {
    // 少了 63 个前导零的 "1"，应等价于完整的 0x01 私钥。
    expect(AppIdentity.isValidPrivateKey('1'), isTrue);
    expect(AppIdentity.addressFromPrivateKey('1'), addressOne);
    expect(AppIdentity.addressFromPrivateKey('0x1'), addressOne);
  });

  test('拒绝零私钥与超出曲线阶的私钥', () {
    expect(AppIdentity.isValidPrivateKey('0' * 64), isFalse, reason: '零不合法');
    expect(
      AppIdentity.isValidPrivateKey(
        'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
      ),
      isFalse,
      reason: '等于 2^256-1，远超曲线阶 N',
    );
    // N 本身也不合法（必须 < N）。
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

  test('拒绝长度不足、过长与非十六进位的输入', () {
    expect(AppIdentity.isValidPrivateKey(''), isFalse);
    expect(AppIdentity.isValidPrivateKey('   '), isFalse);
    // 65 个 hex 字元 → 超过 32 位元组。
    expect(AppIdentity.isValidPrivateKey('1' * 65), isFalse);
    // 含非 hex 字元。
    expect(AppIdentity.isValidPrivateKey('zz' * 32), isFalse);
    expect(AppIdentity.isValidPrivateKey('$privA!'), isFalse);
    // 助记词不是私钥。
    expect(AppIdentity.isValidPrivateKey('apple banana cat'), isFalse);
  });

  test('非法私钥在 fromPrivateKeyHex / addressFromPrivateKey 皆抛出', () async {
    expect(
      () => AppIdentity.addressFromPrivateKey('not-a-key'),
      throwsFormatException,
    );
    await expectLater(
      AppIdentity.fromPrivateKeyHex('not-a-key'),
      throwsFormatException,
    );
  });

  test('同一私钥重复汇入得到相同 DID 与加密公钥（决定性）', () async {
    final first = await AppIdentity.fromPrivateKeyHex(privA);
    final second = await AppIdentity.fromPrivateKeyHex(privA);
    expect(first.did, second.did);
    expect(first.encSeedHex, second.encSeedHex);
    expect(first.encPublicKeyB64, second.encPublicKeyB64);
    expect(first.did, Did.fromAddress(first.address));
  });
}

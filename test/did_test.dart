import 'package:nexuschat/data/crypto/did.dart';
import 'package:test/test.dart';

/// 地址校验与 EIP-55 校验和的验证。
void main() {
  const addr = '0x1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b';
  final upper = '0x${addr.substring(2).toUpperCase()}';

  group('Did.isAddress', () {
    test('全小写与全大写视为未带校验和，一律接受', () {
      expect(Did.isAddress(addr), isTrue);
      expect(Did.isAddress(upper), isTrue);
    });

    test('合法的 EIP-55 校验和地址被接受', () {
      final checksummed = Did.eip55(addr);
      expect(Did.isAddress(checksummed), isTrue);
      expect(Did.hasValidChecksum(checksummed), isTrue);
    });

    test('校验和被改坏的地址一律拒绝', () {
      final checksummed = Did.eip55(addr);

      // 校验和形式的地址是唯一的，所以只要翻转任一个「字母」的大小写，
      // 得到的必然是错的校验和（数字没有大小写，不能拿来翻）。
      var flipAt = -1;
      for (var i = 2; i < checksummed.length; i++) {
        if ('abcdefABCDEF'.contains(checksummed[i])) {
          flipAt = i;
          break;
        }
      }
      expect(flipAt, greaterThan(0), reason: '测试地址应含至少一个字母');

      final original = checksummed[flipAt];
      final flipped =
          original == original.toUpperCase() ? original.toLowerCase() : original.toUpperCase();
      final broken =
          checksummed.substring(0, flipAt) + flipped + checksummed.substring(flipAt + 1);

      expect(Did.hasValidChecksum(broken), isFalse);
      expect(Did.isAddress(broken), isFalse,
          reason: '抄错或被窜改的地址送出就找不回来，必须挡下');
    });

    test('格式不合法的地址被拒绝', () {
      expect(Did.isAddress(''), isFalse);
      expect(Did.isAddress('not-an-address'), isFalse);
      expect(Did.isAddress('0x1234'), isFalse, reason: '长度不足 20 位元组');
      expect(Did.isAddress('0x${'z' * 40}'), isFalse, reason: '非十六进位');
      // 0X 大写前缀不符合 0x 规范。
      expect(Did.isAddress('0X${addr.substring(2)}'), isFalse);
    });
  });
}

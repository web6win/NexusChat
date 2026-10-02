import 'package:nexuschat/data/crypto/did.dart';
import 'package:test/test.dart';

/// 地址校驗與 EIP-55 校驗和的驗證。
void main() {
  const addr = '0x1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b';
  final upper = '0x${addr.substring(2).toUpperCase()}';

  group('Did.isAddress', () {
    test('全小寫與全大寫視為未帶校驗和，一律接受', () {
      expect(Did.isAddress(addr), isTrue);
      expect(Did.isAddress(upper), isTrue);
    });

    test('合法的 EIP-55 校驗和地址被接受', () {
      final checksummed = Did.eip55(addr);
      expect(Did.isAddress(checksummed), isTrue);
      expect(Did.hasValidChecksum(checksummed), isTrue);
    });

    test('校驗和被改壞的地址一律拒絕', () {
      final checksummed = Did.eip55(addr);

      // 校驗和形式的地址是唯一的，所以只要翻轉任一個「字母」的大小寫，
      // 得到的必然是錯的校驗和（數字沒有大小寫，不能拿來翻）。
      var flipAt = -1;
      for (var i = 2; i < checksummed.length; i++) {
        if ('abcdefABCDEF'.contains(checksummed[i])) {
          flipAt = i;
          break;
        }
      }
      expect(flipAt, greaterThan(0), reason: '測試地址應含至少一個字母');

      final original = checksummed[flipAt];
      final flipped =
          original == original.toUpperCase() ? original.toLowerCase() : original.toUpperCase();
      final broken =
          checksummed.substring(0, flipAt) + flipped + checksummed.substring(flipAt + 1);

      expect(Did.hasValidChecksum(broken), isFalse);
      expect(Did.isAddress(broken), isFalse,
          reason: '抄錯或被竄改的地址送出就找不回來，必須擋下');
    });

    test('格式不合法的地址被拒絕', () {
      expect(Did.isAddress(''), isFalse);
      expect(Did.isAddress('not-an-address'), isFalse);
      expect(Did.isAddress('0x1234'), isFalse, reason: '長度不足 20 位元組');
      expect(Did.isAddress('0x${'z' * 40}'), isFalse, reason: '非十六進位');
      // 0X 大寫前綴不符合 0x 規範。
      expect(Did.isAddress('0X${addr.substring(2)}'), isFalse);
    });
  });
}

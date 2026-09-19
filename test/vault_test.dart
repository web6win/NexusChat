import 'dart:convert';

import 'package:nexuschat/data/crypto/app_identity.dart';
import 'package:nexuschat/data/models/identity_hint.dart';
import 'package:nexuschat/data/security/vault.dart';
import 'package:test/test.dart';

/// 測試用低迭代次數：功能驗證不需要 21 萬次（那會讓測試慢上數十倍）。
/// 真正的強度由 [Vault.defaultIterations] 決定，且會寫進密文標頭。
const int _fast = 1000;

const String _password = 'Correct-Horse-Battery-9';

void main() {
  group('Vault 加解密', () {
    test('seal/open 往返可還原原始資料', () async {
      final payload = <String, dynamic>{
        'mnemonic': 'alpha bravo charlie',
        'count': 42,
        'nested': <String, dynamic>{'a': true},
      };
      final blob = await Vault.seal(
        payload: payload,
        password: _password,
        iterations: _fast,
      );
      final opened = await Vault.open(blob: blob, password: _password);

      expect(opened['mnemonic'], 'alpha bravo charlie');
      expect(opened['count'], 42);
      expect((opened['nested'] as Map)['a'], true);
    });

    test('錯誤密碼被拒絕（bad-password）', () async {
      final blob = await Vault.seal(
        payload: <String, dynamic>{'x': 1},
        password: _password,
        iterations: _fast,
      );

      await expectLater(
        () => Vault.open(blob: blob, password: 'not-the-password'),
        throwsA(
          isA<VaultException>().having((e) => e.code, 'code', 'bad-password'),
        ),
      );
    });

    test('大小寫不同的密碼視為不同密碼', () async {
      final blob = await Vault.seal(
        payload: <String, dynamic>{'x': 1},
        password: 'Secret-1234',
        iterations: _fast,
      );
      await expectLater(
        () => Vault.open(blob: blob, password: 'secret-1234'),
        throwsA(isA<VaultException>()),
      );
    });

    test('每次加密使用獨立的 salt 與 nonce', () async {
      final a = await Vault.seal(
        payload: <String, dynamic>{'x': 1},
        password: _password,
        iterations: _fast,
      );
      final b = await Vault.seal(
        payload: <String, dynamic>{'x': 1},
        password: _password,
        iterations: _fast,
      );

      expect(a['salt'], isNot(equals(b['salt'])));
      expect(a['nonce'], isNot(equals(b['nonce'])));
      // 相同明文 + 相同密碼，密文也不應相同。
      expect(a['ct'], isNot(equals(b['ct'])));
      expect(a['mac'], isNot(equals(b['mac'])));
    });

    test('竄改密文會被認證標籤攔下', () async {
      final blob = await Vault.seal(
        payload: <String, dynamic>{'x': 1},
        password: _password,
        iterations: _fast,
      );
      final tampered = Map<String, dynamic>.from(blob);
      final cipherText = tampered['ct'] as String;
      // 只改第一個字元，破壞 GCM 認證。
      tampered['ct'] =
          (cipherText[0] == 'A' ? 'B' : 'A') + cipherText.substring(1);

      await expectLater(
        () => Vault.open(blob: tampered, password: _password),
        throwsA(isA<VaultException>()),
      );
    });

    test('換掉 salt（標頭被動過）也會失敗', () async {
      final blob = await Vault.seal(
        payload: <String, dynamic>{'x': 1},
        password: _password,
        iterations: _fast,
      );
      final tampered = Map<String, dynamic>.from(blob);
      tampered['salt'] = base64Encode(List<int>.filled(32, 7));

      await expectLater(
        () => Vault.open(blob: tampered, password: _password),
        throwsA(isA<VaultException>()),
      );
    });

    test('未知版本被拒絕（unsupported）', () async {
      await expectLater(
        () => Vault.open(
          blob: <String, dynamic>{'v': 99, 'kdf': Vault.kdfName},
          password: 'whatever',
        ),
        throwsA(
          isA<VaultException>().having((e) => e.code, 'code', 'unsupported'),
        ),
      );
    });

    test('結構毀損被拒絕（corrupt）', () async {
      await expectLater(
        () => Vault.open(blob: null, password: 'whatever'),
        throwsA(
          isA<VaultException>().having((e) => e.code, 'code', 'corrupt'),
        ),
      );
      await expectLater(
        () => Vault.open(blob: 'not-a-map', password: 'whatever'),
        throwsA(isA<VaultException>()),
      );
    });

    test('verify 不會拋出，只回報正確與否', () async {
      final blob = await Vault.seal(
        payload: <String, dynamic>{'x': 1},
        password: _password,
        iterations: _fast,
      );
      expect(await Vault.verify(blob: blob, password: _password), isTrue);
      expect(await Vault.verify(blob: blob, password: 'nope'), isFalse);
    });

    test('looksLikeVault 只認自家格式', () {
      expect(Vault.looksLikeVault(null), isFalse);
      expect(Vault.looksLikeVault(<String, dynamic>{}), isFalse);
      expect(
        Vault.looksLikeVault(<String, dynamic>{'kdf': Vault.kdfName}),
        isFalse,
      );
    });

    test('迭代次數記錄在密文標頭並可讀出', () async {
      final blob = await Vault.seal(
        payload: <String, dynamic>{'x': 1},
        password: _password,
        iterations: 4096,
      );
      expect(blob['iterations'], 4096);
      expect(Vault.iterationsOf(blob), 4096);
      expect(Vault.iterationsOf(null), Vault.defaultIterations);
    });
  });

  group('Vault 與真實身份', () {
    test('助記詞身份加密後可完整還原，且密文不含任何秘密', () async {
      final identity = await AppIdentity.generate();
      final blob = await Vault.seal(
        payload: identity.toSecretJson(),
        password: _password,
        iterations: _fast,
      );

      // 序列化後的密文不得出現助記詞、私鑰或加密種子。
      final serialized = jsonEncode(blob);
      expect(identity.mnemonic, isNotEmpty);
      expect(serialized.contains(identity.mnemonic), isFalse);
      expect(serialized.contains(identity.ethPrivateHex), isFalse);
      expect(serialized.contains(identity.encSeedHex), isFalse);
      expect(serialized.contains(identity.encSeedHex.substring(0, 16)), isFalse);

      final opened = await Vault.open(blob: blob, password: _password);
      final restored = AppIdentity.fromSecretJson(opened);
      expect(restored.did, identity.did);
      expect(restored.address, identity.address);
      expect(restored.tronAddress, identity.tronAddress);
      expect(restored.mnemonic, identity.mnemonic);
      expect(restored.ethPrivateHex, identity.ethPrivateHex);
      expect(restored.encSeedHex, identity.encSeedHex);
      expect(restored.encPublicKeyB64, identity.encPublicKeyB64);
    });

    test('公開提示不含任何秘密欄位', () async {
      final identity = await AppIdentity.generate();
      final hint = IdentityHint.fromJson(identity.toHintJson());

      expect(hint, isNotNull);
      expect(hint!.did, identity.did);
      expect(hint.address, identity.address);
      expect(hint.hasMnemonic, isTrue);

      final serialized = jsonEncode(identity.toHintJson());
      expect(serialized.contains(identity.mnemonic), isFalse);
      expect(serialized.contains(identity.ethPrivateHex), isFalse);
      expect(serialized.contains(identity.encSeedHex), isFalse);
      // 金鑰欄位名本身也不該出現。
      expect(serialized.contains('ethPrivateHex'), isFalse);
      expect(serialized.contains('mnemonic'), isFalse);
    });

    test('私鑰身份同樣可還原', () async {
      final identity =
          await AppIdentity.fromPrivateKeyHex('0' * 63 + '1');
      final blob = await Vault.seal(
        payload: identity.toSecretJson(),
        password: _password,
        iterations: _fast,
      );
      final restored =
          AppIdentity.fromSecretJson(await Vault.open(blob: blob, password: _password));
      expect(restored.address, identity.address);
      expect(restored.ethPrivateHex, identity.ethPrivateHex);
      expect(restored.hasMnemonic, isFalse);
    });
  });

  group('PasswordPolicy', () {
    test('太短不合格', () {
      expect(PasswordPolicy.evaluate('abc123').isAcceptable, isFalse);
      expect(PasswordPolicy.evaluate('').isAcceptable, isFalse);
    });

    test('常見密碼一律不合格', () {
      for (final weak in <String>[
        'password',
        'password123',
        '12345678',
        '1234567890',
        'qwerty123',
        'nexuschat123',
        'letmein1',
      ]) {
        expect(
          PasswordPolicy.evaluate(weak).isAcceptable,
          isFalse,
          reason: '$weak 不應被接受',
        );
      }
    });

    test('單一字元重複或連續數字不合格', () {
      expect(PasswordPolicy.evaluate('aaaaaaaaaaaa').isAcceptable, isFalse);
      expect(
        PasswordPolicy.evaluate('012345678901').isAcceptable,
        isFalse,
      );
    });

    test('夠長且多樣的密碼合格', () {
      final strength = PasswordPolicy.evaluate('Correct-Horse-9');
      expect(strength.isAcceptable, isTrue);
      expect(strength.score, greaterThanOrEqualTo(2));
      expect(strength.label, 'strong');
    });

    test('強度標籤隨複雜度提升', () {
      expect(PasswordPolicy.evaluate('abcdefgh').label, 'weak');
      expect(PasswordPolicy.evaluate('Abcdefg1').score,
          greaterThanOrEqualTo(2));
    });
  });
}

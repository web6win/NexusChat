import 'dart:convert';

import 'package:nexuschat/data/crypto/app_identity.dart';
import 'package:nexuschat/data/models/identity_hint.dart';
import 'package:nexuschat/data/security/vault.dart';
import 'package:test/test.dart';

/// 测试用低迭代次数：功能验证不需要 21 万次（那会让测试慢上数十倍）。
/// 真正的强度由 [Vault.defaultIterations] 决定，且会写进密文标头。
const int _fast = 1000;

const String _password = 'Correct-Horse-Battery-9';

void main() {
  group('Vault 加解密', () {
    test('seal/open 往返可还原原始资料', () async {
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

    test('错误密码被拒绝（bad-password）', () async {
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

    test('大小写不同的密码视为不同密码', () async {
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

    test('每次加密使用独立的 salt 与 nonce', () async {
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
      // 相同明文 + 相同密码，密文也不应相同。
      expect(a['ct'], isNot(equals(b['ct'])));
      expect(a['mac'], isNot(equals(b['mac'])));
    });

    test('窜改密文会被认证标签拦下', () async {
      final blob = await Vault.seal(
        payload: <String, dynamic>{'x': 1},
        password: _password,
        iterations: _fast,
      );
      final tampered = Map<String, dynamic>.from(blob);
      final cipherText = tampered['ct'] as String;
      // 只改第一个字元，破坏 GCM 认证。
      tampered['ct'] =
          (cipherText[0] == 'A' ? 'B' : 'A') + cipherText.substring(1);

      await expectLater(
        () => Vault.open(blob: tampered, password: _password),
        throwsA(isA<VaultException>()),
      );
    });

    test('换掉 salt（标头被动过）也会失败', () async {
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

    test('未知版本被拒绝（unsupported）', () async {
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

    test('结构毁损被拒绝（corrupt）', () async {
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

    test('verify 不会抛出，只回报正确与否', () async {
      final blob = await Vault.seal(
        payload: <String, dynamic>{'x': 1},
        password: _password,
        iterations: _fast,
      );
      expect(await Vault.verify(blob: blob, password: _password), isTrue);
      expect(await Vault.verify(blob: blob, password: 'nope'), isFalse);
    });

    test('looksLikeVault 只认自家格式', () {
      expect(Vault.looksLikeVault(null), isFalse);
      expect(Vault.looksLikeVault(<String, dynamic>{}), isFalse);
      expect(
        Vault.looksLikeVault(<String, dynamic>{'kdf': Vault.kdfName}),
        isFalse,
      );
    });

    test('迭代次数记录在密文标头并可读出', () async {
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

  group('Vault 与真实身份', () {
    test('助记词身份加密后可完整还原，且密文不含任何秘密', () async {
      final identity = await AppIdentity.generate();
      final blob = await Vault.seal(
        payload: identity.toSecretJson(),
        password: _password,
        iterations: _fast,
      );

      // 序列化后的密文不得出现助记词、私钥或加密种子。
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

    test('公开提示不含任何秘密栏位', () async {
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
      // 金钥栏位名本身也不该出现。
      expect(serialized.contains('ethPrivateHex'), isFalse);
      expect(serialized.contains('mnemonic'), isFalse);
    });

    test('私钥身份同样可还原', () async {
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

    test('常见密码一律不合格', () {
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
          reason: '$weak 不应被接受',
        );
      }
    });

    test('单一字元重复或连续数字不合格', () {
      expect(PasswordPolicy.evaluate('aaaaaaaaaaaa').isAcceptable, isFalse);
      expect(
        PasswordPolicy.evaluate('012345678901').isAcceptable,
        isFalse,
      );
    });

    test('够长且多样的密码合格', () {
      final strength = PasswordPolicy.evaluate('Correct-Horse-9');
      expect(strength.isAcceptable, isTrue);
      expect(strength.score, greaterThanOrEqualTo(2));
      expect(strength.label, 'strong');
    });

    test('强度标签随复杂度提升', () {
      expect(PasswordPolicy.evaluate('abcdefgh').label, 'weak');
      expect(PasswordPolicy.evaluate('Abcdefg1').score,
          greaterThanOrEqualTo(2));
    });
  });
}

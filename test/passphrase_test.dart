import 'dart:convert';

import 'package:nexuschat/data/crypto/app_identity.dart';
import 'package:nexuschat/data/security/vault.dart';
import 'package:test/test.dart';

/// 功能验证不需要 21 万次迭代（那会让测试慢上数十倍）。
const int _fast = 1000;

Future<String> _mnemonic() async =>
    (await AppIdentity.generate()).mnemonic;

void main() {
  group('BIP39 密码短语', () {
    test('同一组助记词配上不同短语会得到不同身份', () async {
      final mnemonic = await _mnemonic();
      final without = await AppIdentity.fromMnemonic(mnemonic);
      final withPhrase =
          await AppIdentity.fromMnemonic(mnemonic, passphrase: 'correct horse');

      expect(withPhrase.address, isNot(without.address));
      expect(withPhrase.did, isNot(without.did));
      expect(withPhrase.ethPrivateHex, isNot(without.ethPrivateHex));
    });

    test('相同助记词 + 相同短语可重现同一个身份', () async {
      final mnemonic = await _mnemonic();
      final a = await AppIdentity.fromMnemonic(mnemonic, passphrase: 'nexus');
      final b = await AppIdentity.fromMnemonic(mnemonic, passphrase: 'nexus');

      expect(a.address, b.address);
      expect(a.ethPrivateHex, b.ethPrivateHex);
      expect(a.encPublicKeyB64, b.encPublicKeyB64);
    });

    test('短语区分大小写与空白', () async {
      final mnemonic = await _mnemonic();
      final lower = await AppIdentity.fromMnemonic(mnemonic, passphrase: 'alpha');
      final upper = await AppIdentity.fromMnemonic(mnemonic, passphrase: 'Alpha');
      final trailing =
          await AppIdentity.fromMnemonic(mnemonic, passphrase: 'Alpha ');

      expect(upper.address, isNot(lower.address));
      expect(upper.address, isNot(trailing.address));
    });

    test('不带短语与空短语等价（既有身份不受影响）', () async {
      final mnemonic = await _mnemonic();
      final a = await AppIdentity.fromMnemonic(mnemonic);
      final b = await AppIdentity.fromMnemonic(mnemonic, passphrase: '');

      expect(a.address, b.address);
      expect(a.hasPassphrase, isFalse);
    });

    test('短语是秘密：只进保险库密文，不进公开提示', () async {
      final identity =
          await AppIdentity.fromMnemonic(await _mnemonic(), passphrase: 'top secret');

      expect(identity.hasPassphrase, isTrue);

      // 公开提示在锁屏时也会被读取，绝对不能出现短语。
      final hint = jsonEncode(identity.toHintJson());
      expect(hint.contains('top secret'), isFalse);
      expect(hint.contains('passphrase'), isFalse);

      final blob = await Vault.seal(
        payload: identity.toSecretJson(),
        password: 'vault-password',
        iterations: _fast,
      );
      expect(jsonEncode(blob).contains('top secret'), isFalse);

      final restored = AppIdentity.fromSecretJson(
        await Vault.open(blob: blob, password: 'vault-password'),
      );
      expect(restored.passphrase, 'top secret');
      expect(restored.address, identity.address);
    });

    test('旧版密文没有 passphrase 栏位时视为未使用', () {
      final identity = AppIdentity.fromJson(<String, dynamic>{
        'mnemonic': 'alpha bravo charlie',
        'did': 'did:ethr:0x1',
        'address': '0x1',
        'tronAddress': 'T',
        'ethPrivateHex': 'aa',
        'ethPublicHex': 'bb',
        'encSeedHex': 'cc',
        'encPublicKeyB64': 'AA==',
      });

      expect(identity.passphrase, '');
      expect(identity.hasPassphrase, isFalse);
    });

    test('私钥汇入的身份没有助记词也没有短语', () async {
      final identity =
          await AppIdentity.fromPrivateKeyHex('0' * 63 + '1');

      expect(identity.hasMnemonic, isFalse);
      expect(identity.hasPassphrase, isFalse);
    });
  });
}

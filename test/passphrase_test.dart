import 'dart:convert';

import 'package:nexuschat/data/crypto/app_identity.dart';
import 'package:nexuschat/data/security/vault.dart';
import 'package:test/test.dart';

/// 功能驗證不需要 21 萬次迭代（那會讓測試慢上數十倍）。
const int _fast = 1000;

Future<String> _mnemonic() async =>
    (await AppIdentity.generate()).mnemonic;

void main() {
  group('BIP39 密碼短語', () {
    test('同一組助記詞配上不同短語會得到不同身份', () async {
      final mnemonic = await _mnemonic();
      final without = await AppIdentity.fromMnemonic(mnemonic);
      final withPhrase =
          await AppIdentity.fromMnemonic(mnemonic, passphrase: 'correct horse');

      expect(withPhrase.address, isNot(without.address));
      expect(withPhrase.did, isNot(without.did));
      expect(withPhrase.ethPrivateHex, isNot(without.ethPrivateHex));
    });

    test('相同助記詞 + 相同短語可重現同一個身份', () async {
      final mnemonic = await _mnemonic();
      final a = await AppIdentity.fromMnemonic(mnemonic, passphrase: 'nexus');
      final b = await AppIdentity.fromMnemonic(mnemonic, passphrase: 'nexus');

      expect(a.address, b.address);
      expect(a.ethPrivateHex, b.ethPrivateHex);
      expect(a.encPublicKeyB64, b.encPublicKeyB64);
    });

    test('短語區分大小寫與空白', () async {
      final mnemonic = await _mnemonic();
      final lower = await AppIdentity.fromMnemonic(mnemonic, passphrase: 'alpha');
      final upper = await AppIdentity.fromMnemonic(mnemonic, passphrase: 'Alpha');
      final trailing =
          await AppIdentity.fromMnemonic(mnemonic, passphrase: 'Alpha ');

      expect(upper.address, isNot(lower.address));
      expect(upper.address, isNot(trailing.address));
    });

    test('不帶短語與空短語等價（既有身份不受影響）', () async {
      final mnemonic = await _mnemonic();
      final a = await AppIdentity.fromMnemonic(mnemonic);
      final b = await AppIdentity.fromMnemonic(mnemonic, passphrase: '');

      expect(a.address, b.address);
      expect(a.hasPassphrase, isFalse);
    });

    test('短語是秘密：只進保險庫密文，不進公開提示', () async {
      final identity =
          await AppIdentity.fromMnemonic(await _mnemonic(), passphrase: 'top secret');

      expect(identity.hasPassphrase, isTrue);

      // 公開提示在鎖屏時也會被讀取，絕對不能出現短語。
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

    test('舊版密文沒有 passphrase 欄位時視為未使用', () {
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

    test('私鑰匯入的身份沒有助記詞也沒有短語', () async {
      final identity =
          await AppIdentity.fromPrivateKeyHex('0' * 63 + '1');

      expect(identity.hasMnemonic, isFalse);
      expect(identity.hasPassphrase, isFalse);
    });
  });
}

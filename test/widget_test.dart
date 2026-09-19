import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:nexuschat/core/utils/hex.dart';
import 'package:nexuschat/data/crypto/app_identity.dart';
import 'package:nexuschat/data/crypto/crypto_service.dart';
import 'package:nexuschat/data/crypto/did.dart';
import 'package:nexuschat/data/ethereum/ethereum_service.dart';
import 'package:nexuschat/data/waku/content_topics.dart';
import 'package:nexuschat/data/waku/envelope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Hex 編解碼來回一致', () {
    final bytes = Uint8List.fromList(<int>[0, 1, 15, 16, 255]);
    expect(Hex.decode(Hex.encode(bytes)), bytes);
    expect(Hex.decode('0x00ff'), <int>[0, 255]);
  });

  test('DID 由地址產生並可反解', () {
    const address = '0x1234567890AbcdEF1234567890aBcdef12345678';
    final did = Did.fromAddress(address);
    expect(did.startsWith('did:ethr:0x'), isTrue);
    expect(Did.toAddress(did), address.toLowerCase());
    expect(Did.isEnsName('vitalik.eth'), isTrue);
  });

  test('namehash 對空字串回傳 32 位元組零值', () {
    final node = EthereumService.namehash('');
    expect(node.length, 32);
    expect(node.every((b) => b == 0), isTrue);
  });

  test('content topic 由雙方 DID 對稱派生', () {
    const a = 'did:ethr:0xaaa';
    const b = 'did:ethr:0xbbb';
    expect(
      ContentTopics.directMessage(a, b),
      ContentTopics.directMessage(b, a),
    );
  });

  test('端到端加密：只有持有私鑰的人能解開', () async {
    final alice = await AppIdentity.generate();
    final bob = await AppIdentity.generate();
    final aliceCrypto = await CryptoService.create(alice);
    final bobCrypto = await CryptoService.create(bob);

    final sealed = await aliceCrypto.seal('hello waku', bob.encPublicKeyB64);
    expect(await bobCrypto.open(sealed), 'hello waku');

    final attacker =
        await CryptoService.create(await AppIdentity.generate());
    expect(await attacker.open(sealed), isNull);
  });

  test('封包簽章可被驗證且無法偽造', () async {
    final alice = await AppIdentity.generate();
    final bob = await AppIdentity.generate();
    final aliceCrypto = await CryptoService.create(alice);

    final sealer = EnvelopeSealer(aliceCrypto);
    final envelope = await sealer.seal(
      type: EnvelopeType.chat,
      from: alice.did,
      to: bob.did,
      plaintext: 'signed message',
      recipientPublicKeyB64: bob.encPublicKeyB64,
    );
    expect(
      CryptoService.verifyDid(
        alice.did,
        envelope.signingPayload,
        envelope.signature!,
      ),
      isTrue,
    );
    expect(
      CryptoService.verifyDid(
        bob.did,
        envelope.signingPayload,
        envelope.signature!,
      ),
      isFalse,
    );
  });
}

// ignore_for_file: avoid_print

// 命令列冒煙測試：不依賴 flutter_test，直接以 `dart run tool/smoke.dart` 執行。
// 驗證身份派生、端到端加密與簽章驗證的核心邏輯。
import 'dart:typed_data';

import 'package:nexuschat/core/utils/hex.dart';
import 'package:nexuschat/data/crypto/app_identity.dart';
import 'package:nexuschat/data/crypto/crypto_service.dart';
import 'package:nexuschat/data/crypto/did.dart';
import 'package:nexuschat/data/ethereum/ethereum_service.dart';
import 'package:nexuschat/data/waku/content_topics.dart';
import 'package:nexuschat/data/waku/envelope.dart';
import 'package:nexuschat/data/waku/waku_transport.dart';

void check(bool condition, String message) {
  if (!condition) {
    throw StateError('❌ $message');
  }
  print('✅ $message');
}

Future<void> main() async {
  // ------------------------------------------------------------------ HEX
  final bytes = Uint8List.fromList(<int>[0, 1, 15, 16, 255]);
  check(Hex.decode(Hex.encode(bytes)).toString() == bytes.toString(),
      'Hex 編解碼來回一致');
  check(Hex.decode('0x00ff').toString() == '[0, 255]', 'Hex 處理 0x 前綴');

  // ------------------------------------------------------------------ DID
  const address = '0x1234567890AbcdEF1234567890aBcdef12345678';
  final did = Did.fromAddress(address);
  check(did.startsWith('did:ethr:0x'), 'DID 以 did:ethr 開頭');
  check(Did.toAddress(did) == address.toLowerCase(), 'DID 可反解地址');
  check(Did.isEnsName('vitalik.eth'), 'ENS 名稱判斷');

  // --------------------------------------------------------------- namehash
  final node = EthereumService.namehash('');
  check(node.length == 32 && node.every((b) => b == 0), 'namehash 空值為 32 零位元組');

  // ------------------------------------------------------------ content topic
  check(
    ContentTopics.directMessage('did:ethr:0xaaa', 'did:ethr:0xbbb') ==
        ContentTopics.directMessage('did:ethr:0xbbb', 'did:ethr:0xaaa'),
    '一對一 topic 由雙方對稱派生',
  );

  // ------------------------------------------------------------- 身份與加密
  final alice = await AppIdentity.generate();
  final aliceRestored = await AppIdentity.fromMnemonic(alice.mnemonic);
  check(aliceRestored.did == alice.did, '助記詞可還原出相同 DID');
  check(
    aliceRestored.encPublicKeyB64 == alice.encPublicKeyB64,
    '助記詞可還原出相同加密公鑰',
  );

  final bob = await AppIdentity.generate();
  final aliceCrypto = await CryptoService.create(alice);
  final bobCrypto = await CryptoService.create(bob);

  final sealed = await aliceCrypto.seal('hello waku', bob.encPublicKeyB64);
  check(await bobCrypto.open(sealed) == 'hello waku', '接收者可解密訊息');

  final attacker = await CryptoService.create(await AppIdentity.generate());
  check(await attacker.open(sealed) == null, '第三方無法解密');

  final tampered = EncryptedBlob(
    cipherText: sealed.cipherText,
    mac: sealed.mac,
    nonce: sealed.nonce,
    ephemeralPublicKey: sealed.ephemeralPublicKey,
  );
  check(await bobCrypto.open(tampered) == 'hello waku', '相同封包可重複解密');

  // ------------------------------------------------------------------ 簽章
  final sealer = EnvelopeSealer(aliceCrypto);
  final envelope = await sealer.seal(
    type: EnvelopeType.chat,
    from: alice.did,
    to: bob.did,
    plaintext: 'signed message',
    recipientPublicKeyB64: bob.encPublicKeyB64,
  );
  check(
    CryptoService.verifyDid(
      alice.did,
      envelope.signingPayload,
      envelope.signature!,
    ),
    '簽章可由 DID 驗證',
  );
  check(
    !CryptoService.verifyDid(
      bob.did,
      envelope.signingPayload,
      envelope.signature!,
    ),
    '簽章無法被他人冒用',
  );
  check(envelope.encodeBase64().isNotEmpty, '封包可序列化為 Base64');
  check(
    NexusChatEnvelope.decodeBase64(envelope.encodeBase64())?.id == envelope.id,
    '封包可由 Base64 還原',
  );
  check(
    await sealer.open(envelope).then((r) => r?.plaintext) == 'signed message',
    '封包可解開為明文',
  );

  // ------------------------------------------------------------ 傳輸模式遷移
  check(
    TransportKind.fromValue('nwaku-rest') == TransportKind.nwakuRest,
    'nwaku REST 設定可正確還原',
  );
  check(
    TransportKind.fromValue('loopback') == TransportKind.nwakuRest,
    '舊版 loopback 設定會升級為 nwaku REST',
  );
  check(
    TransportKind.fromValue(null) == TransportKind.nwakuRest,
    '未設定時預設使用 nwaku REST',
  );

  print('\n🎉 全部冒煙測試通過');
}

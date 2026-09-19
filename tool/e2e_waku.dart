// 端到端聊天測試：兩個真實身份，各自連一個 nwaku 節點，
// 走完整的「發布金鑰包 → 發現對方公鑰 → 加密私訊 → 對方解密 → 回覆」流程。
//
// ignore_for_file: avoid_print

// 用法：
//   dart run tool/e2e_waku.dart
//   dart run tool/e2e_waku.dart http://10.37.0.110:8645 http://10.37.0.110:8646
import 'package:nexuschat/data/crypto/app_identity.dart';
import 'package:nexuschat/data/crypto/crypto_service.dart';
import 'package:nexuschat/data/waku/content_topics.dart';
import 'package:nexuschat/data/waku/envelope.dart';
import 'package:nexuschat/data/waku/nwaku_rest_transport.dart';
import 'package:nexuschat/data/waku/waku_service.dart';

int _passed = 0;
int _failed = 0;

void check(String label, bool ok, [String detail = '']) {
  if (ok) {
    _passed++;
    print('  PASS  $label${detail.isEmpty ? '' : '  ($detail)'}');
  } else {
    _failed++;
    print('  FAIL  $label${detail.isEmpty ? '' : '  ($detail)'}');
  }
}

Future<void> main(List<String> args) async {
  final nodeA = args.isNotEmpty ? args[0] : 'http://127.0.0.1:8645';
  final nodeB = args.length > 1 ? args[1] : 'http://127.0.0.1:8646';

  print('=== NexusChat 端到端聊天測試 ===');
  print('節點 A（Alice）: $nodeA');
  print('節點 B（Bob）  : $nodeB');
  print('');

  // ---------------------------------------------------------------- 身份
  print('[1] 建立身份');
  final aliceId = await AppIdentity.generate();
  final bobId = await AppIdentity.generate();
  final aliceCrypto = await CryptoService.create(aliceId);
  final bobCrypto = await CryptoService.create(bobId);
  check('Alice DID', aliceId.did.startsWith('did:ethr:0x'), aliceId.did);
  check('Bob DID', bobId.did.startsWith('did:ethr:0x'), bobId.did);
  check('兩者 DID 不同', aliceId.did != bobId.did);

  // ---------------------------------------------------------------- 傳輸
  print('[2] 連線節點');
  final aliceTransport = NwakuRestTransport(baseUrl: nodeA);
  final bobTransport = NwakuRestTransport(baseUrl: nodeB);
  await aliceTransport.start();
  await bobTransport.start();
  final healthA = await aliceTransport.health();
  final healthB = await bobTransport.health();
  check('節點 A 健康', healthA.ok, '${healthA.latencyMs}ms');
  check('節點 B 健康', healthB.ok, '${healthB.latencyMs}ms');
  if (!healthA.ok || !healthB.ok) {
    print('\n節點未就緒，終止。');
    return;
  }

  final alice = WakuService(
    transport: aliceTransport,
    identity: aliceId,
    crypto: aliceCrypto,
  );
  final bob = WakuService(
    transport: bobTransport,
    identity: bobId,
    crypto: bobCrypto,
  );

  // ---------------------------------------------------------------- 金鑰包
  print('[3] 雙方發布金鑰包');
  await alice.publishKeyBundle(nickname: 'Alice');
  await bob.publishKeyBundle(nickname: 'Bob');
  print('  已發布，等待網路傳播...');
  await Future<void>.delayed(const Duration(seconds: 5));

  // 各自從自己的節點找對方的金鑰包
  String? aliceFoundBobKey;
  String? bobFoundAliceKey;

  Future<String?> findPeerKey(
    WakuService self,
    String peerDid, [
    String who = '',
  ]) async {
    final messages =
        await self.fetch(<String>[ContentTopics.keyBundle], limit: 200);
    final seenFrom = <String>[];
    for (final message in messages) {
      final envelope = NexusChatEnvelope.decodeBase64(message.payloadBase64);
      if (envelope == null) continue;
      final opened = await self.sealer.open(envelope);
      if (opened == null) {
        seenFrom.add('${envelope.from}(簽章失敗)');
        continue;
      }
      seenFrom.add(envelope.from);
      if (envelope.from.toLowerCase() != peerDid.toLowerCase()) continue;
      final pub = envelope.publicData?['enc'] as String?;
      if (pub != null && pub.isNotEmpty) return pub;
    }
    if (who.isNotEmpty) {
      print('    $who 看到 ${messages.length} 則金鑰包：${seenFrom.join(', ')}');
      print('    $who 要找的是：$peerDid');
      for (final m in messages) {
        final raw = m.payloadBase64;
        print('      raw[${raw.length}]=${raw.substring(0, raw.length > 90 ? 90 : raw.length)}');
      }
    }
    return null;
  }

  print('[4] 互相發現對方公鑰');
  for (var i = 0; i < 8; i++) {
    final verbose = i >= 2; // 前兩輪不吵，之後印出診斷
    aliceFoundBobKey ??=
        await findPeerKey(alice, bobId.did, verbose ? 'Alice' : '');
    bobFoundAliceKey ??= await findPeerKey(bob, aliceId.did, verbose ? 'Bob' : '');
    if (aliceFoundBobKey != null && bobFoundAliceKey != null) break;
    await Future<void>.delayed(const Duration(seconds: 3));
  }
  check('Alice 取得 Bob 的加密公鑰', aliceFoundBobKey != null);
  check('Bob 取得 Alice 的加密公鑰', bobFoundAliceKey != null);
  if (aliceFoundBobKey == null || bobFoundAliceKey == null) {
    print('\n金鑰交換失敗，終止。');
    return;
  }
  check(
    '雙方算出的私訊 topic 一致',
    ContentTopics.directMessage(aliceId.did, bobId.did) ==
        ContentTopics.directMessage(bobId.did, aliceId.did),
    ContentTopics.directMessage(aliceId.did, bobId.did),
  );

  // ---------------------------------------------------------------- 私訊
  const aliceText = '你好 Bob，這是來自 Alice 的端到端加密訊息 / E2E test 123';
  print('[5] Alice → Bob 發送加密訊息');
  await alice.sendText(
    toDid: bobId.did,
    recipientPublicKeyB64: aliceFoundBobKey,
    text: aliceText,
  );

  final dmTopic = ContentTopics.directMessage(aliceId.did, bobId.did);
  String? bobReceived;
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(const Duration(seconds: 3));
    final messages = await bob.fetch(<String>[dmTopic], limit: 200);
    for (final message in messages) {
      final envelope = NexusChatEnvelope.decodeBase64(message.payloadBase64);
      if (envelope == null) continue;
      if (envelope.from.toLowerCase() != aliceId.did.toLowerCase()) continue;
      final opened = await bob.sealer.open(envelope);
      if (opened?.plaintext != null) {
        bobReceived = opened!.plaintext;
        break;
      }
    }
    if (bobReceived != null) break;
  }
  check('Bob 收到並解密', bobReceived != null);
  check('內容完全一致', bobReceived == aliceText, bobReceived ?? '(null)');

  // ---------------------------------------------------------------- 回覆
  const bobText = '收到！我是 Bob，回覆一條加密訊息 / reply ✔';
  print('[6] Bob → Alice 回覆');
  await bob.sendText(
    toDid: aliceId.did,
    recipientPublicKeyB64: bobFoundAliceKey,
    text: bobText,
  );

  String? aliceReceived;
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(const Duration(seconds: 3));
    final messages = await alice.fetch(<String>[dmTopic], limit: 200);
    for (final message in messages) {
      final envelope = NexusChatEnvelope.decodeBase64(message.payloadBase64);
      if (envelope == null) continue;
      if (envelope.from.toLowerCase() != bobId.did.toLowerCase()) continue;
      final opened = await alice.sealer.open(envelope);
      if (opened?.plaintext != null) {
        aliceReceived = opened!.plaintext;
        break;
      }
    }
    if (aliceReceived != null) break;
  }
  check('Alice 收到並解密回覆', aliceReceived != null);
  check('回覆內容一致', aliceReceived == bobText, aliceReceived ?? '(null)');

  // ------------------------------------------------- 陌生人來訊（收件匣）
  // 回歸測試：Bob 完全沒把 Carol 加進聯絡人，因此不會輪詢 pairwise 頻道，
  // 只輪詢自己的收件匣。這種情況下第一則訊息也必須收得到。
  print('[7] 陌生人第一則訊息（對方不在聯絡人清單）');
  final carolId = await AppIdentity.generate();
  final carolCrypto = await CryptoService.create(carolId);
  final carol = WakuService(
    transport: NwakuRestTransport(baseUrl: nodeA)..start(),
    identity: carolId,
    crypto: carolCrypto,
  );

  String? carolFoundBobKey;
  for (var i = 0; i < 6; i++) {
    final bundles = await carol.fetch(<String>[ContentTopics.keyBundle]);
    for (final message in bundles) {
      final envelope = NexusChatEnvelope.decodeBase64(message.payloadBase64);
      if (envelope == null) continue;
      if (envelope.from.toLowerCase() != bobId.did.toLowerCase()) continue;
      carolFoundBobKey = envelope.publicData?['enc'] as String?;
    }
    if (carolFoundBobKey != null) break;
    await Future<void>.delayed(const Duration(seconds: 3));
  }
  check('Carol 從金鑰包頻道取得 Bob 公鑰', carolFoundBobKey != null);

  const carolText = '嗨 Bob，我是陌生人 Carol / first-contact test';
  final carolSent = await carol.sendText(
    toDid: bobId.did,
    recipientPublicKeyB64: carolFoundBobKey!,
    text: carolText,
    senderName: 'Carol',
  );
  check(
    '封包附帶暱稱（客戶端可自動建立名片）',
    carolSent.publicData?['name'] == 'Carol',
    '${carolSent.publicData}',
  );

  // Bob 只輪詢「沒有任何聯絡人」時會訂閱的頻道（收件匣 + 金鑰包）
  final bobDefaultTopics = bob.topicsFor(const <String>[]);
  check(
    'Bob 的預設頻道包含收件匣',
    bobDefaultTopics.contains(ContentTopics.inbox(bobId.did)),
    bobDefaultTopics.join(' , '),
  );

  String? bobGotFromStranger;
  String? strangerEncKey;
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(const Duration(seconds: 3));
    final messages = await bob.fetch(bobDefaultTopics, limit: 200);
    for (final message in messages) {
      final envelope = NexusChatEnvelope.decodeBase64(message.payloadBase64);
      if (envelope == null) continue;
      if (envelope.from.toLowerCase() != carolId.did.toLowerCase()) continue;
      final opened = await bob.sealer.open(envelope);
      if (opened?.plaintext != null) {
        bobGotFromStranger = opened!.plaintext;
        strangerEncKey = envelope.publicData?['enc'] as String?;
        break;
      }
    }
    if (bobGotFromStranger != null) break;
  }
  check('Bob 沒加 Carol 也收得到', bobGotFromStranger != null);
  check('陌生人訊息內容一致', bobGotFromStranger == carolText,
      bobGotFromStranger ?? '(null)');
  check(
    '封包附帶發送者公鑰（可立即回覆）',
    strangerEncKey != null && strangerEncKey == carolId.encPublicKeyB64,
  );
  // ------------------------------------------------- 即時推播（filter v2）
  // 回歸測試：訂閱後節點會主動把訊息收進 filter 快取，客戶端用 1.2 秒的
  // 節奏取走即可，不需要等 store 那類較重的查詢。
  print('[8] filter 推播即時接收');
  final pushTopic = ContentTopics.inbox(bobId.did);
  await bob.subscribe(<String>[pushTopic]);
  final pushText = '即時推播 ${DateTime.now().millisecondsSinceEpoch}';
  final sw = Stopwatch()..start();
  await alice.sendText(
    toDid: bobId.did,
    recipientPublicKeyB64: aliceFoundBobKey,
    text: pushText,
  );
  String? pushReceived;
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final messages = await bob.fetch(<String>[pushTopic], sinceMs: 0, limit: 50);
    for (final message in messages) {
      final envelope = NexusChatEnvelope.decodeBase64(message.payloadBase64);
      if (envelope == null) continue;
      final opened = await bob.sealer.open(envelope);
      if (opened?.plaintext == pushText) {
        pushReceived = opened!.plaintext;
        break;
      }
    }
    if (pushReceived != null) break;
  }
  sw.stop();
  check('filter 推播收得到', pushReceived != null);
  check(
    '延遲在 6 秒內（${sw.elapsedMilliseconds}ms）',
    sw.elapsedMilliseconds < 6000,
  );
  // ---------------------------------------------------------------- 竊聽者
  print('[9] 第三方無法解密');
  final eveId = await AppIdentity.generate();
  final eveCrypto = await CryptoService.create(eveId);
  final eve = WakuService(
    transport: NwakuRestTransport(baseUrl: nodeB)..start(),
    identity: eveId,
    crypto: eveCrypto,
  );
  var eveDecrypted = false;
  final eveMessages = await eve.fetch(<String>[dmTopic], limit: 200);
  for (final message in eveMessages) {
    final envelope = NexusChatEnvelope.decodeBase64(message.payloadBase64);
    if (envelope == null) continue;
    final opened = await eve.sealer.open(envelope);
    if (opened?.plaintext != null) eveDecrypted = true;
  }
  check('Eve 解不開（簽章驗證或解密失敗）', !eveDecrypted);
  check('網路上確實看得到密文（非空白）', eveMessages.isNotEmpty,
      '${eveMessages.length} 則訊息，但皆無法解開');

  // ---------------------------------------------------------------- 收尾
  aliceTransport.dispose();
  bobTransport.dispose();
  print('');
  print('=== 結果：$_passed 通過 / $_failed 失敗 ===');
  if (_failed > 0) throw StateError('$_failed 項失敗');
}

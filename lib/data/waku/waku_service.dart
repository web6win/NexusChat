import '../crypto/app_identity.dart';
import '../crypto/crypto_service.dart';
import '../models/chat_models.dart';
import '../models/group_models.dart';
import 'content_topics.dart';
import 'envelope.dart';
import 'message_content.dart';
import 'waku_message.dart';
import 'waku_transport.dart';

/// Waku 服务：把「封包 ↔ 网路」的细节封装起来，上层只需处理语意。
class WakuService {
  WakuService({
    required this.transport,
    required this.identity,
    required this.crypto,
  }) {
    sealer = EnvelopeSealer(crypto);
  }

  final WakuTransport transport;
  final AppIdentity identity;
  final CryptoService crypto;

  late final EnvelopeSealer sealer;

  String get did => identity.did;

  Future<void> start() => transport.start();

  Future<void> stop() => transport.stop();

  /// 停止连线并释放底层资源（HTTP 连线池等）。
  Future<void> dispose() async {
    await transport.stop();
    transport.dispose();
  }

  /// 把自己的加密公钥与暱称广播出去，让别人能加密讯息给自己。
  Future<void> publishKeyBundle({String? nickname}) async {
    final envelope = sealer.sealPublic(
      type: EnvelopeType.keyBundle,
      from: identity.did,
      publicData: <String, dynamic>{
        'did': identity.did,
        'enc': identity.encPublicKeyB64,
        'name': nickname ?? '',
        'address': identity.address,
      },
    );
    await publishEnvelope(envelope, topic: ContentTopics.keyBundle);
  }

  /// 送出一段文字给某个 DID。
  ///
  /// 同时发到两个频道：
  /// - [ContentTopics.directMessage]：双方都认识彼此时的常规频道；
  /// - [ContentTopics.inbox]：只由收件人 DID 派生，对方即使还没把你加入
  ///   联络人（因此不会轮询 pairwise 频道）也收得到。
  ///
  /// 两个频道放的是同一个封包，收件端靠 `envelope.id` 去重。
  Future<NexusChatEnvelope> sendText({
    required String toDid,
    required String recipientPublicKeyB64,
    required String text,
    String? senderName,
  }) =>
      sendContent(
        toDid: toDid,
        recipientPublicKeyB64: recipientPublicKeyB64,
        content: MessageContent.text(text),
        senderName: senderName,
      );

  /// 送出任意内容（文字 / 图片 / 语音）给某个 DID。
  ///
  /// 图片等媒体体积较大，不写入「给自己的副本」（[includeSelfCopy]），
  /// 因为发送端本机已经保存了这则讯息；这也能避免信封因自带副本而超过
  /// Waku 的单则大小上限。
  Future<NexusChatEnvelope> sendContent({
    required String toDid,
    required String recipientPublicKeyB64,
    required MessageContent content,
    String? senderName,
  }) async {
    final envelope = await sealer.seal(
      type: EnvelopeType.chat,
      from: identity.did,
      to: toDid,
      plaintext: content.encode(),
      recipientPublicKeyB64: recipientPublicKeyB64,
      // 附上自己的加密公钥与暱称：对方即使没在金钥包频道看过你，
      // 也能立刻回复，并在通讯录里建立你的名片。
      publicData: <String, dynamic>{
        'enc': identity.encPublicKeyB64,
        if (senderName != null && senderName.isNotEmpty) 'name': senderName,
      },
      includeSelfCopy: content.kind == MediaKind.text,
    );
    final topics = <String>{
      ContentTopics.directMessage(identity.did, toDid),
      ContentTopics.inbox(toDid),
    };
    for (final topic in topics) {
      await publishEnvelope(envelope, topic: topic);
    }
    return envelope;
  }

  /// 送出输入中状态（不进 store，避免占用空间）。
  Future<void> sendTyping(String toDid) async {
    final envelope = sealer.sealPublic(
      type: EnvelopeType.typing,
      from: identity.did,
      publicData: <String, dynamic>{'to': toDid},
    );
    await publishEnvelope(
      envelope,
      topic: ContentTopics.directMessage(identity.did, toDid),
      ephemeral: true,
    );
  }

  /// 广播「撤回某则讯息」的通知。
  ///
  /// 去中心化网路无法真的把讯息从对方装置上抹掉，所以撤回的做法是：
  /// 在一对一频道与对方收件匣各发一则撤回通知，收到的一端把该讯息
  /// 标记为已撤回，介面改显示「讯息已撤回」。
  ///
  /// 刻意只签章、不加密：[publicData] 只带讯息 ID，且这样即使对方
  /// 还没拿到我们的加密金钥，撤回也一定送得出去、收得到。
  Future<NexusChatEnvelope> sendRecall({
    required String toDid,
    required String targetMessageId,
  }) async {
    final envelope = sealer.sealPublic(
      type: EnvelopeType.recall,
      from: identity.did,
      publicData: <String, dynamic>{
        'target': targetMessageId,
        'to': toDid,
      },
    );
    for (final topic in <String>{
      ContentTopics.directMessage(identity.did, toDid),
      ContentTopics.inbox(toDid),
    }) {
      await publishEnvelope(envelope, topic: topic);
    }
    return envelope;
  }

  /// 传送群组邀请：把群组金钥用收件人公钥加密，发到其收件匣与一对一频道。
  Future<NexusChatEnvelope> sendGroupInvite({
    required String toDid,
    required Map<String, dynamic> invite,
    required String recipientPublicKeyB64,
  }) async {
    final envelope = await sealer.sealGroupInvite(
      from: identity.did,
      to: toDid,
      payload: invite,
      recipientPublicKeyB64: recipientPublicKeyB64,
    );
    for (final topic in <String>{
      ContentTopics.directMessage(identity.did, toDid),
      ContentTopics.inbox(toDid),
    }) {
      await publishEnvelope(envelope, topic: topic);
    }
    return envelope;
  }

  /// 传送群组讯息：用共享对称金钥加密，发到群组专属频道。
  Future<NexusChatEnvelope> sendGroupContent({
    required String groupId,
    required List<int> key,
    required MessageContent content,
    String? senderName,
  }) async {
    final envelope = await sealer.sealGroup(
      from: identity.did,
      groupId: groupId,
      key: key,
      plaintext: content.encode(),
      publicData: <String, dynamic>{
        'enc': identity.encPublicKeyB64,
        if (senderName != null && senderName.isNotEmpty) 'name': senderName,
      },
    );
    await publishEnvelope(
      envelope,
      topic: ContentTopics.group(groupId),
    );
    return envelope;
  }

  /// 广播群组内的撤回通知：发到群组频道，[to] 为 `grp:<groupId>`。
  Future<NexusChatEnvelope> sendGroupRecall({
    required String groupId,
    required String targetMessageId,
  }) async {
    final envelope = sealer.sealPublic(
      type: EnvelopeType.recall,
      from: identity.did,
      publicData: <String, dynamic>{
        'target': targetMessageId,
        'to': 'grp:$groupId',
      },
    );
    await publishEnvelope(
      envelope,
      topic: ContentTopics.group(groupId),
    );
    return envelope;
  }

  /// 需要轮询的群组频道（成员所属的群组）。
  List<String> topicsForGroups(Iterable<GroupChat> groups) {
    final topics = <String>{};
    for (final group in groups) {
      topics.add(ContentTopics.group(group.id));
    }
    return topics.toList(growable: false);
  }

  Future<void> publishEnvelope(
    NexusChatEnvelope envelope, {
    required String topic,
    bool ephemeral = false,
  }) {
    return transport.publish(
      WakuMessage.fromMillis(
        contentTopic: topic,
        payloadBase64: envelope.encodeBase64(),
        timestampMs: envelope.timestampMs,
        ephemeral: ephemeral,
      ),
    );
  }

  /// 需要轮询的所有 topic：自己的收件匣 + 金钥包频道 + 每个联络人的
  /// 一对一频道。
  ///
  /// 收件匣一定在清单里，所以「对方加了我、我还没加对方」也能收得到第一则
  /// 讯息；金钥包频道则用来补齐联络人的加密公钥。
  List<String> topicsFor(Iterable<String> peerDids) {
    final topics = <String>{
      ContentTopics.keyBundle,
      ContentTopics.inbox(identity.did),
    };
    for (final peer in peerDids) {
      topics.add(ContentTopics.directMessage(identity.did, peer));
    }
    return topics.toList(growable: false);
  }

  /// 请节点开始把这些频道的讯息推播给我们（即时接收的关键）。
  ///
  /// 节点不支援 filter 时会静默略过，[fetch] 仍会退回一般轮询。
  Future<void> subscribe(List<String> contentTopics) =>
      transport.subscribe(contentTopics);

  Future<List<WakuMessage>> fetch(
    List<String> contentTopics, {
    int? sinceMs,
    int limit = 100,
  }) {
    return transport.query(
      contentTopics: contentTopics,
      sinceMs: sinceMs,
      limit: limit,
    );
  }

  Future<TransportHealth> health() => transport.health();
}

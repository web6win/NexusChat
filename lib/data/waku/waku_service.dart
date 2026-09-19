import '../crypto/app_identity.dart';
import '../crypto/crypto_service.dart';
import '../models/chat_models.dart';
import 'content_topics.dart';
import 'envelope.dart';
import 'message_content.dart';
import 'waku_message.dart';
import 'waku_transport.dart';

/// Waku 服務：把「封包 ↔ 網路」的細節封裝起來，上層只需處理語意。
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

  /// 停止連線並釋放底層資源（HTTP 連線池等）。
  Future<void> dispose() async {
    await transport.stop();
    transport.dispose();
  }

  /// 把自己的加密公鑰與暱稱廣播出去，讓別人能加密訊息給自己。
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

  /// 送出一段文字給某個 DID。
  ///
  /// 同時發到兩個頻道：
  /// - [ContentTopics.directMessage]：雙方都認識彼此時的常規頻道；
  /// - [ContentTopics.inbox]：只由收件人 DID 派生，對方即使還沒把你加入
  ///   聯絡人（因此不會輪詢 pairwise 頻道）也收得到。
  ///
  /// 兩個頻道放的是同一個封包，收件端靠 `envelope.id` 去重。
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

  /// 送出任意內容（文字 / 圖片 / 語音）給某個 DID。
  ///
  /// 圖片等媒體體積較大，不寫入「給自己的副本」（[includeSelfCopy]），
  /// 因為發送端本機已經保存了這則訊息；這也能避免信封因自帶副本而超過
  /// Waku 的單則大小上限。
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
      // 附上自己的加密公鑰與暱稱：對方即使沒在金鑰包頻道看過你，
      // 也能立刻回覆，並在通訊錄裡建立你的名片。
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

  /// 送出輸入中狀態（不進 store，避免佔用空間）。
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

  /// 需要輪詢的所有 topic：自己的收件匣 + 金鑰包頻道 + 每個聯絡人的
  /// 一對一頻道。
  ///
  /// 收件匣一定在清單裡，所以「對方加了我、我還沒加對方」也能收得到第一則
  /// 訊息；金鑰包頻道則用來補齊聯絡人的加密公鑰。
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

  /// 請節點開始把這些頻道的訊息推播給我們（即時接收的關鍵）。
  ///
  /// 節點不支援 filter 時會靜默略過，[fetch] 仍會退回一般輪詢。
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

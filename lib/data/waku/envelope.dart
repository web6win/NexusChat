import 'dart:convert';

import 'package:meta/meta.dart' show immutable;
import 'package:uuid/uuid.dart';

import '../../core/utils/hex.dart' show B64;
import '../crypto/crypto_service.dart';

/// 通讯协定的封包类型。
enum EnvelopeType {
  /// 一般聊天讯息。
  chat('chat'),

  /// 已读回条。
  receipt('receipt'),

  /// 正在输入（ephemeral）。
  typing('typing'),

  /// 金钥包公布。
  keyBundle('keybundle'),

  /// 撤回某则讯息（墓碑通知）：携带要撤回的讯息 ID。
  recall('recall'),

  /// 群组邀请：携带群组金钥与成员清单，用收件人公钥加密。
  groupInvite('groupinvite');

  const EnvelopeType(this.value);

  final String value;

  static EnvelopeType fromValue(String? value) {
    for (final t in EnvelopeType.values) {
      if (t.value == value) return t;
    }
    return EnvelopeType.chat;
  }
}

/// 在 Waku 网路上流动的封包。
///
/// 明文栏位（v / id / type / from / to / ts）只有最基本的中继资讯，
/// 真正内容一律放在 [body]（加密给收件人）与 [selfBody]（加密给自己）。
@immutable
class NexusChatEnvelope {
  const NexusChatEnvelope({
    required this.id,
    required this.type,
    required this.from,
    required this.to,
    required this.timestampMs,
    this.body,
    this.selfBody,
    this.publicData,
    this.signature,
  });

  final String id;
  final EnvelopeType type;

  /// 发送者 DID。
  final String from;

  /// 收件者 DID（金钥包类型为 '*'）。
  final String to;

  final int timestampMs;

  /// 加密给收件人的内容。
  final EncryptedBlob? body;

  /// 加密给自己的副本（多装置同步用）。
  final EncryptedBlob? selfBody;

  /// 不需要加密的公开栏位（例如金钥包里的暱称与公钥）。
  final Map<String, dynamic>? publicData;

  /// secp256k1 签章（`r:s:v`，16 进位）。
  final String? signature;

  /// 产生签章时所使用的正规化字串。
  String get signingPayload {
    final ct = body?.cipherText ?? '';
    return 'nexuschat|1|$id|${type.value}|${from.toLowerCase()}|${to.toLowerCase()}|$timestampMs|$ct';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'v': 1,
        'id': id,
        'type': type.value,
        'from': from,
        'to': to,
        'ts': timestampMs,
        if (body != null) 'body': body!.toJson(),
        if (selfBody != null) 'self': selfBody!.toJson(),
        if (publicData != null) 'pub': publicData,
        if (signature != null) 'sig': signature,
      };

  /// 序列化为 UTF-8 JSON 字串（Waku payload 会再转 Base64）。
  String encode() => jsonEncode(toJson());

  /// 序列化后再转 Base64，直接作为 Waku payload。
  String encodeBase64() => B64.encode(utf8.encode(encode()));

  /// 由 Base64 payload 还原封包。
  static NexusChatEnvelope? decodeBase64(String source) {
    try {
      return decode(utf8.decode(B64.decode(source)));
    } catch (_) {
      return null;
    }
  }

  static NexusChatEnvelope? decode(String source) {
    try {
      final raw = jsonDecode(source);
      if (raw is! Map) return null;
      return fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  static NexusChatEnvelope? fromJson(Map<dynamic, dynamic> raw) {
    final id = raw['id'];
    final from = raw['from'];
    final ts = raw['ts'];
    if (id is! String || from is! String || ts is! int) return null;
    return NexusChatEnvelope(
      id: id,
      type: EnvelopeType.fromValue(raw['type'] as String?),
      from: from,
      to: (raw['to'] as String?) ?? '*',
      timestampMs: ts,
      body: EncryptedBlob.fromJson(raw['body']),
      selfBody: EncryptedBlob.fromJson(raw['self']),
      publicData: raw['pub'] is Map
          ? Map<String, dynamic>.from(raw['pub'] as Map)
          : null,
      signature: raw['sig'] as String?,
    );
  }
}

/// 加密与签章的组合工具：把 [NexusChatEnvelope] 填满密文与签章，
/// 或者在收到时验证并解开。
class EnvelopeSealer {
  EnvelopeSealer(this._crypto);

  final CryptoService _crypto;

  /// 产生并签章一个封包。
  Future<NexusChatEnvelope> seal({
    required EnvelopeType type,
    required String from,
    required String to,
    required String plaintext,
    required String recipientPublicKeyB64,
    Map<String, dynamic>? publicData,
    bool includeSelfCopy = true,
  }) async {
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final id = _newId();
    final body = await _crypto.seal(
      plaintext,
      recipientPublicKeyB64,
      aad: utf8.encode('$from|$to|$timestamp'),
    );
    final selfBody = includeSelfCopy
        ? await _crypto.sealSelf(
            plaintext,
            aad: utf8.encode('$from|$to|$timestamp'),
          )
        : null;

    final envelope = NexusChatEnvelope(
      id: id,
      type: type,
      from: from,
      to: to,
      timestampMs: timestamp,
      body: body,
      selfBody: selfBody,
      publicData: publicData,
    );
    return envelope.copyWith(signature: _crypto.signHex(envelope.signingPayload));
  }

  /// 只签章、不加密（金钥包等公开资料）。
  NexusChatEnvelope sealPublic({
    required EnvelopeType type,
    required String from,
    required Map<String, dynamic> publicData,
  }) {
    final envelope = NexusChatEnvelope(
      id: _newId(),
      type: type,
      from: from,
      to: '*',
      timestampMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      publicData: publicData,
    );
    return envelope.copyWith(signature: _crypto.signHex(envelope.signingPayload));
  }

  /// 解开并验证一个封包；验证失败或解密失败回传 null。
  Future<EnvelopeOpenResult?> open(NexusChatEnvelope envelope) async {
    final signature = envelope.signature;
    if (signature == null) return null;
    if (!CryptoService.verifyDid(
      envelope.from,
      envelope.signingPayload,
      signature,
    )) {
      return null;
    }

    final aad = utf8.encode(
      '${envelope.from}|${envelope.to}|${envelope.timestampMs}',
    );
    String? text;
    final body = envelope.body;
    final selfBody = envelope.selfBody;
    if (body != null) {
      text = await _crypto.open(body, aad: aad);
    }
    if (text == null && selfBody != null) {
      text = await _crypto.open(selfBody, aad: aad);
    }
    if (text == null && body == null && selfBody == null) {
      // 纯公开封包（例如金钥包）
      return EnvelopeOpenResult(envelope: envelope, plaintext: null);
    }
    if (text == null) return null;
    return EnvelopeOpenResult(envelope: envelope, plaintext: text);
  }

  /// 群组邀请：把 [payload]（含群组金钥）用收件人公钥加密后送出。
  Future<NexusChatEnvelope> sealGroupInvite({
    required String from,
    required String to,
    required Map<String, dynamic> payload,
    required String recipientPublicKeyB64,
  }) async {
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final id = _newId();
    final body = await _crypto.seal(
      jsonEncode(payload),
      recipientPublicKeyB64,
      aad: utf8.encode('$to|$id'),
    );
    final envelope = NexusChatEnvelope(
      id: id,
      type: EnvelopeType.groupInvite,
      from: from,
      to: to,
      timestampMs: timestamp,
      body: body,
    );
    return envelope.copyWith(signature: _crypto.signHex(envelope.signingPayload));
  }

  /// 群组讯息：用共享对称金钥加密，[to] 为 `grp:<groupId>`。
  Future<NexusChatEnvelope> sealGroup({
    required String from,
    required String groupId,
    required List<int> key,
    required String plaintext,
    Map<String, dynamic>? publicData,
  }) async {
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final id = _newId();
    final body = await _crypto.sealSymmetric(
      plaintext,
      key,
      aad: utf8.encode('$groupId|$timestamp'),
    );
    final envelope = NexusChatEnvelope(
      id: id,
      type: EnvelopeType.chat,
      from: from,
      to: 'grp:$groupId',
      timestampMs: timestamp,
      body: body,
      publicData: publicData,
    );
    return envelope.copyWith(signature: _crypto.signHex(envelope.signingPayload));
  }

  /// 解开群组讯息：验章后用共享对称金钥解密。失败回传 null。
  Future<EnvelopeOpenResult?> openGroup(
    NexusChatEnvelope envelope,
    List<int> key,
  ) async {
    final signature = envelope.signature;
    if (signature == null) return null;
    final groupId = envelope.to.startsWith('grp:')
        ? envelope.to.substring(4)
        : envelope.to;
    if (!CryptoService.verifyDid(
      envelope.from,
      envelope.signingPayload,
      signature,
    )) {
      return null;
    }
    final aad = utf8.encode('$groupId|${envelope.timestampMs}');
    final body = envelope.body;
    if (body == null) return null;
    final text = await _crypto.openSymmetric(body, key, aad: aad);
    if (text == null) return null;
    return EnvelopeOpenResult(envelope: envelope, plaintext: text);
  }

  static const Uuid _uuid = Uuid();

  String _newId() => _uuid.v4();

  /// 短识别码（用于 UI 显示的讯息编号）。
  String newShortId() => _uuid.v4().substring(0, 8);
}

/// 解开后的结果。
@immutable
class EnvelopeOpenResult {
  const EnvelopeOpenResult({required this.envelope, required this.plaintext});

  final NexusChatEnvelope envelope;

  /// 解密后的明文（讯息内容的 JSON 序列化字串）；公开封包为 null。
  final String? plaintext;
}

/// 让 [NexusChatEnvelope] 具备 copyWith。
extension NexusChatEnvelopeCopy on NexusChatEnvelope {
  NexusChatEnvelope copyWith({
    String? id,
    EnvelopeType? type,
    String? from,
    String? to,
    int? timestampMs,
    EncryptedBlob? body,
    EncryptedBlob? selfBody,
    Map<String, dynamic>? publicData,
    String? signature,
  }) {
    return NexusChatEnvelope(
      id: id ?? this.id,
      type: type ?? this.type,
      from: from ?? this.from,
      to: to ?? this.to,
      timestampMs: timestampMs ?? this.timestampMs,
      body: body ?? this.body,
      selfBody: selfBody ?? this.selfBody,
      publicData: publicData ?? this.publicData,
      signature: signature ?? this.signature,
    );
  }
}

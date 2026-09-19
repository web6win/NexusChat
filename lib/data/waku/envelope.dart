import 'dart:convert';

import 'package:meta/meta.dart' show immutable;
import 'package:uuid/uuid.dart';

import '../../core/utils/hex.dart' show B64;
import '../crypto/crypto_service.dart';

/// 通訊協定的封包類型。
enum EnvelopeType {
  /// 一般聊天訊息。
  chat('chat'),

  /// 已讀回條。
  receipt('receipt'),

  /// 正在輸入（ephemeral）。
  typing('typing'),

  /// 金鑰包公布。
  keyBundle('keybundle');

  const EnvelopeType(this.value);

  final String value;

  static EnvelopeType fromValue(String? value) {
    for (final t in EnvelopeType.values) {
      if (t.value == value) return t;
    }
    return EnvelopeType.chat;
  }
}

/// 在 Waku 網路上流動的封包。
///
/// 明文欄位（v / id / type / from / to / ts）只有最基本的中繼資訊，
/// 真正內容一律放在 [body]（加密給收件人）與 [selfBody]（加密給自己）。
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

  /// 發送者 DID。
  final String from;

  /// 收件者 DID（金鑰包類型為 '*'）。
  final String to;

  final int timestampMs;

  /// 加密給收件人的內容。
  final EncryptedBlob? body;

  /// 加密給自己的副本（多裝置同步用）。
  final EncryptedBlob? selfBody;

  /// 不需要加密的公開欄位（例如金鑰包裡的暱稱與公鑰）。
  final Map<String, dynamic>? publicData;

  /// secp256k1 簽章（`r:s:v`，16 進位）。
  final String? signature;

  /// 產生簽章時所使用的正規化字串。
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

  /// 序列化為 UTF-8 JSON 字串（Waku payload 會再轉 Base64）。
  String encode() => jsonEncode(toJson());

  /// 序列化後再轉 Base64，直接作為 Waku payload。
  String encodeBase64() => B64.encode(utf8.encode(encode()));

  /// 由 Base64 payload 還原封包。
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

/// 加密與簽章的組合工具：把 [NexusChatEnvelope] 填滿密文與簽章，
/// 或者在收到時驗證並解開。
class EnvelopeSealer {
  EnvelopeSealer(this._crypto);

  final CryptoService _crypto;

  /// 產生並簽章一個封包。
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

  /// 只簽章、不加密（金鑰包等公開資料）。
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

  /// 解開並驗證一個封包；驗證失敗或解密失敗回傳 null。
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
      // 純公開封包（例如金鑰包）
      return EnvelopeOpenResult(envelope: envelope, plaintext: null);
    }
    if (text == null) return null;
    return EnvelopeOpenResult(envelope: envelope, plaintext: text);
  }

  static const Uuid _uuid = Uuid();

  String _newId() => _uuid.v4();

  /// 短識別碼（用於 UI 顯示的訊息編號）。
  String newShortId() => _uuid.v4().substring(0, 8);
}

/// 解開後的結果。
@immutable
class EnvelopeOpenResult {
  const EnvelopeOpenResult({required this.envelope, required this.plaintext});

  final NexusChatEnvelope envelope;

  /// 解密後的明文（訊息內容的 JSON 序列化字串）；公開封包為 null。
  final String? plaintext;
}

/// 讓 [NexusChatEnvelope] 具備 copyWith。
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

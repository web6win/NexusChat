import 'dart:convert';
import 'dart:typed_data';

import '../models/chat_models.dart';

/// 封裝在 Waku 信封裡的「訊息內容」。
///
/// 文字、圖片、語音都由此物件描述，再序列化成 JSON 字串作為信封的明文
/// （加密前）。圖片/語音的原始位元組以 Base64 內嵌，確保明文一定是字串，
/// 能直接交給既有的 AES-GCM 加密流程。
class MessageContent {
  const MessageContent._({
    required this.kind,
    required this.text,
    this.mediaBytes,
    this.mediaMime,
    this.mediaDurationMs,
    this.mediaName,
  });

  /// 純文字訊息。
  factory MessageContent.text(String text) => MessageContent._(
        kind: MediaKind.text,
        text: text,
      );

  /// 圖片訊息。
  factory MessageContent.image({
    required String text,
    required Uint8List mediaBytes,
    String mediaMime = 'image/jpeg',
    String? mediaName,
  }) =>
      MessageContent._(
        kind: MediaKind.image,
        text: text,
        mediaBytes: mediaBytes,
        mediaMime: mediaMime,
        mediaName: mediaName,
      );

  /// 語音訊息。
  factory MessageContent.audio({
    required Uint8List mediaBytes,
    String mediaMime = 'audio/aac',
    int? mediaDurationMs,
    String? mediaName,
    String text = '',
  }) =>
      MessageContent._(
        kind: MediaKind.audio,
        text: text,
        mediaBytes: mediaBytes,
        mediaMime: mediaMime,
        mediaDurationMs: mediaDurationMs,
        mediaName: mediaName,
      );

  final MediaKind kind;
  final String text;
  final Uint8List? mediaBytes;
  final String? mediaMime;
  final int? mediaDurationMs;
  final String? mediaName;

  /// 序列化為信封明文（JSON 字串）。
  String encode() {
    final map = <String, dynamic>{
      't': kind.value,
      'text': text,
    };
    if (mediaBytes != null) map['b64'] = base64Encode(mediaBytes!);
    if (mediaMime != null) map['mime'] = mediaMime;
    if (mediaDurationMs != null) map['dur'] = mediaDurationMs;
    if (mediaName != null) map['name'] = mediaName;
    return jsonEncode(map);
  }

  /// 由信封明文還原；舊版純文字會被當作文字訊息以維持相容。
  static MessageContent decode(String raw) {
    try {
      final parsed = jsonDecode(raw);
      if (parsed is Map && parsed['t'] is String) {
        final t = parsed['t'] as String;
        final text = (parsed['text'] as String?) ?? '';
        final b64 = parsed['b64'] as String?;
        final bytes = b64 == null ? null : base64Decode(b64);
        final mime = parsed['mime'] as String?;
        final dur = parsed['dur'] as int?;
        final name = parsed['name'] as String?;
        switch (t) {
          case 'image':
            return MessageContent.image(
              text: text,
              mediaBytes: bytes ?? Uint8List(0),
              mediaMime: mime ?? 'image/jpeg',
              mediaName: name,
            );
          case 'audio':
            return MessageContent.audio(
              mediaBytes: bytes ?? Uint8List(0),
              mediaMime: mime ?? 'audio/aac',
              mediaDurationMs: dur,
              mediaName: name,
              text: text,
            );
          default:
            return MessageContent.text(text);
        }
      }
    } catch (_) {
      // 解析失敗：視為舊版純文字。
    }
    return MessageContent.text(raw);
  }

  /// 由已儲存的 [ChatMessage] 重建（用於失敗重試）。
  factory MessageContent.fromChatMessage(ChatMessage message) {
    final bytes = message.mediaB64 == null
        ? null
        : base64Decode(message.mediaB64!);
    switch (message.kind) {
      case MediaKind.image:
        return MessageContent.image(
          text: message.text,
          mediaBytes: bytes ?? Uint8List(0),
          mediaMime: message.mediaMime ?? 'image/jpeg',
          mediaName: message.mediaName,
        );
      case MediaKind.audio:
        return MessageContent.audio(
          mediaBytes: bytes ?? Uint8List(0),
          mediaMime: message.mediaMime ?? 'audio/aac',
          mediaDurationMs: message.mediaDurationMs,
          mediaName: message.mediaName,
          text: message.text,
        );
      case MediaKind.text:
        return MessageContent.text(message.text);
    }
  }
}

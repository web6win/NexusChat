import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/material.dart' show Color;

import '../crypto/did.dart';

/// 一則聊天訊息的傳遞狀態。
enum MessageStatus {
  /// 已交給傳輸層，尚未確認。
  sending('sending'),

  /// 已發布到 Waku。
  sent('sent'),

  /// 對方已收到（保留欄位）。
  delivered('delivered'),

  /// 對方已讀。
  read('read'),

  /// 發送失敗。
  failed('failed');

  const MessageStatus(this.value);

  final String value;

  static MessageStatus fromValue(String? value) {
    for (final s in MessageStatus.values) {
      if (s.value == value) return s;
    }
    return MessageStatus.sent;
  }
}

/// 訊息的內容種類。
enum MediaKind {
  /// 純文字。
  text('text'),

  /// 圖片（JPEG/PNG，已加密）。
  image('image'),

  /// 語音訊息（AAC/Opus 等，已加密）。
  audio('audio');

  const MediaKind(this.value);

  final String value;

  static MediaKind fromValue(String? value) {
    for (final k in MediaKind.values) {
      if (k.value == value) return k;
    }
    return MediaKind.text;
  }
}

/// 本地保存的訊息。
@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.peerDid,
    required this.text,
    required this.timestampMs,
    required this.outgoing,
    this.status = MessageStatus.sent,
    this.error,
    this.kind = MediaKind.text,
    this.mediaB64,
    this.mediaMime,
    this.mediaDurationMs,
    this.mediaName,
  });

  /// 封包 ID（同時作為去重鍵）。
  final String id;

  /// 對方的 DID（= 對話 ID）。
  final String peerDid;

  /// 文字內容；圖片/語音時為選用說明（caption）。
  final String text;

  final int timestampMs;

  final bool outgoing;

  final MessageStatus status;

  /// 失敗原因（若有）。
  final String? error;

  /// 內容種類。
  final MediaKind kind;

  /// 媒體原始 bytes 的 Base64（圖片/語音）。文字訊息為 null。
  final String? mediaB64;

  /// 媒體 MIME，例如 image/jpeg、audio/aac。
  final String? mediaMime;

  /// 語音時長（毫秒）。
  final int? mediaDurationMs;

  /// 原始檔名（若有）。
  final String? mediaName;

  DateTime get timestamp =>
      DateTime.fromMillisecondsSinceEpoch(timestampMs, isUtc: true);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'peerDid': peerDid,
        'text': text,
        'ts': timestampMs,
        'out': outgoing,
        'status': status.value,
        'kind': kind.value,
        if (mediaB64 != null) 'media': mediaB64,
        if (mediaMime != null) 'mmime': mediaMime,
        if (mediaDurationMs != null) 'mdur': mediaDurationMs,
        if (mediaName != null) 'mname': mediaName,
        if (error != null) 'error': error,
      };

  static ChatMessage? fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return null;
    final id = json['id'];
    final peerDid = json['peerDid'];
    final ts = json['ts'];
    if (id is! String || peerDid is! String || ts is! int) return null;
    return ChatMessage(
      id: id,
      peerDid: peerDid,
      text: (json['text'] as String?) ?? '',
      timestampMs: ts,
      outgoing: (json['out'] as bool?) ?? false,
      status: MessageStatus.fromValue(json['status'] as String?),
      kind: MediaKind.fromValue(json['kind'] as String?),
      mediaB64: json['media'] as String?,
      mediaMime: json['mmime'] as String?,
      mediaDurationMs: json['mdur'] as int?,
      mediaName: json['mname'] as String?,
      error: json['error'] as String?,
    );
  }

  ChatMessage copyWith({
    String? id,
    String? peerDid,
    String? text,
    int? timestampMs,
    bool? outgoing,
    MessageStatus? status,
    String? error,
    MediaKind? kind,
    String? mediaB64,
    String? mediaMime,
    int? mediaDurationMs,
    String? mediaName,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      peerDid: peerDid ?? this.peerDid,
      text: text ?? this.text,
      timestampMs: timestampMs ?? this.timestampMs,
      outgoing: outgoing ?? this.outgoing,
      status: status ?? this.status,
      error: error ?? this.error,
      kind: kind ?? this.kind,
      mediaB64: mediaB64 ?? this.mediaB64,
      mediaMime: mediaMime ?? this.mediaMime,
      mediaDurationMs: mediaDurationMs ?? this.mediaDurationMs,
      mediaName: mediaName ?? this.mediaName,
    );
  }
}

/// 一個聯絡人。
@immutable
class Contact {
  const Contact({
    required this.did,
    required this.name,
    this.ens,
    this.encPublicKeyB64,
    this.addedAtMs,
    this.isDemo = false,
    this.accentValue,
    this.bio,
  });

  final String did;

  /// 顯示名稱（暱稱 → ENS → 短地址）。
  final String name;

  final String? ens;

  /// 對方的 X25519 公鑰（取得後才能加密訊息）。
  final String? encPublicKeyB64;

  final int? addedAtMs;

  /// 是否為內建示範帳號。
  final bool isDemo;

  final int? accentValue;

  final String? bio;

  bool get hasKey => encPublicKeyB64 != null && encPublicKeyB64!.isNotEmpty;

  /// 頭像底色：示範帳號用指定色，其餘由 DID 派生。
  Color get accent {
    if (accentValue != null) return Color(accentValue!);
    const palette = <Color>[
      Color(0xFF6C5CE7),
      Color(0xFF22D3EE),
      Color(0xFFF59E0B),
      Color(0xFF16A34A),
      Color(0xFFEF4444),
      Color(0xFF8B5CF6),
    ];
    var hash = 0;
    for (final unit in did.codeUnits) {
      hash = (hash * 31 + unit) & 0x7FFFFFFF;
    }
    return palette[hash % palette.length];
  }

  /// 頭像文字。
  String get initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return Did.shortAddress(did).substring(2, 4);
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
  }

  Contact copyWith({
    String? did,
    String? name,
    String? ens,
    String? encPublicKeyB64,
    int? addedAtMs,
    bool? isDemo,
    int? accentValue,
    String? bio,
  }) {
    return Contact(
      did: did ?? this.did,
      name: name ?? this.name,
      ens: ens ?? this.ens,
      encPublicKeyB64: encPublicKeyB64 ?? this.encPublicKeyB64,
      addedAtMs: addedAtMs ?? this.addedAtMs,
      isDemo: isDemo ?? this.isDemo,
      accentValue: accentValue ?? this.accentValue,
      bio: bio ?? this.bio,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'did': did,
        'name': name,
        if (ens != null) 'ens': ens,
        if (encPublicKeyB64 != null) 'enc': encPublicKeyB64,
        'addedAtMs': addedAtMs ?? DateTime.now().millisecondsSinceEpoch,
        'isDemo': isDemo,
        if (accentValue != null) 'accent': accentValue,
        if (bio != null) 'bio': bio,
      };

  static Contact? fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return null;
    final did = json['did'];
    if (did is! String) return null;
    return Contact(
      did: did,
      name: (json['name'] as String?) ?? Did.shortDid(did),
      ens: json['ens'] as String?,
      encPublicKeyB64: json['enc'] as String?,
      addedAtMs: json['addedAtMs'] as int?,
      isDemo: (json['isDemo'] as bool?) ?? false,
      accentValue: json['accent'] as int?,
      bio: json['bio'] as String?,
    );
  }
}

/// 對話列表中的一筆。
@immutable
class Conversation {
  const Conversation({
    required this.peerDid,
    required this.title,
    this.lastText = '',
    this.lastTsMs = 0,
    this.unread = 0,
    this.lastStatus,
    this.pinned = false,
    this.draft = '',
    this.lastMedia,
  });

  /// 與 [peerDid] 相同，方便直接作為 key。
  final String peerDid;

  final String title;

  final String lastText;

  final int lastTsMs;

  final int unread;

  final MessageStatus? lastStatus;

  final bool pinned;

  /// 尚未送出的草稿。
  final String draft;

  /// 最後一則訊息的媒體種類（'image' / 'audio' / null），用於列表預覽。
  final String? lastMedia;

  String get id => peerDid;

  Conversation copyWith({
    String? peerDid,
    String? title,
    String? lastText,
    int? lastTsMs,
    int? unread,
    MessageStatus? lastStatus,
    bool? pinned,
    String? draft,
    String? lastMedia,
  }) {
    return Conversation(
      peerDid: peerDid ?? this.peerDid,
      title: title ?? this.title,
      lastText: lastText ?? this.lastText,
      lastTsMs: lastTsMs ?? this.lastTsMs,
      unread: unread ?? this.unread,
      lastStatus: lastStatus ?? this.lastStatus,
      pinned: pinned ?? this.pinned,
      draft: draft ?? this.draft,
      lastMedia: lastMedia ?? this.lastMedia,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'peerDid': peerDid,
        'title': title,
        'lastText': lastText,
        'lastTsMs': lastTsMs,
        'unread': unread,
        if (lastStatus != null) 'lastStatus': lastStatus!.value,
        'pinned': pinned,
        'draft': draft,
        if (lastMedia != null) 'lastMedia': lastMedia,
      };

  static Conversation? fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return null;
    final peerDid = json['peerDid'];
    if (peerDid is! String) return null;
    return Conversation(
      peerDid: peerDid,
      title: (json['title'] as String?) ?? Did.shortDid(peerDid),
      lastText: (json['lastText'] as String?) ?? '',
      lastTsMs: (json['lastTsMs'] as int?) ?? 0,
      unread: (json['unread'] as int?) ?? 0,
      lastStatus: MessageStatus.fromValue(json['lastStatus'] as String?),
      pinned: (json['pinned'] as bool?) ?? false,
      draft: (json['draft'] as String?) ?? '',
      lastMedia: json['lastMedia'] as String?,
    );
  }
}

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/material.dart' show Color;

import '../crypto/did.dart';

/// 一则聊天讯息的传递状态。
enum MessageStatus {
  /// 已交给传输层，尚未确认。
  sending('sending'),

  /// 已发布到 Waku。
  sent('sent'),

  /// 对方已收到（保留栏位）。
  delivered('delivered'),

  /// 对方已读。
  read('read'),

  /// 发送失败。
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

/// 讯息的内容种类。
enum MediaKind {
  /// 纯文字。
  text('text'),

  /// 图片（JPEG/PNG，已加密）。
  image('image'),

  /// 语音讯息（AAC/Opus 等，已加密）。
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

/// 本地保存的讯息。
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
    this.recalledAtMs,
    this.senderDid,
  });

  /// 封包 ID（同时作为去重键）。
  final String id;

  /// 对方的 DID（= 对话 ID）。
  final String peerDid;

  /// 文字内容；图片/语音时为选用说明（caption）。
  final String text;

  final int timestampMs;

  final bool outgoing;

  final MessageStatus status;

  /// 失败原因（若有）。
  final String? error;

  /// 内容种类。
  final MediaKind kind;

  /// 媒体原始 bytes 的 Base64（图片/语音）。文字讯息为 null。
  final String? mediaB64;

  /// 媒体 MIME，例如 image/jpeg、audio/aac。
  final String? mediaMime;

  /// 语音时长（毫秒）。
  final int? mediaDurationMs;

  /// 原始档名（若有）。
  final String? mediaName;

  /// 撤回时间（毫秒）。非 null 表示这则讯息已被撤回，内容不再显示。
  final int? recalledAtMs;

  /// 群组讯息的发送者 DID（一对一讯息为 null，由 [peerDid] 隐含）。
  final String? senderDid;

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
        if (recalledAtMs != null) 'recalledAt': recalledAtMs,
        if (senderDid != null) 'sender': senderDid,
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
      recalledAtMs: json['recalledAt'] as int?,
      senderDid: json['sender'] as String?,
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
    int? recalledAtMs,
    String? senderDid,
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
      recalledAtMs: recalledAtMs ?? this.recalledAtMs,
      senderDid: senderDid ?? this.senderDid,
    );
  }
}

/// 一个联络人。
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

  /// 显示名称（暱称 → ENS → 短地址）。
  final String name;

  final String? ens;

  /// 对方的 X25519 公钥（取得后才能加密讯息）。
  final String? encPublicKeyB64;

  final int? addedAtMs;

  /// 是否为内建示范帐号。
  final bool isDemo;

  final int? accentValue;

  final String? bio;

  bool get hasKey => encPublicKeyB64 != null && encPublicKeyB64!.isNotEmpty;

  /// 头像底色：示范帐号用指定色，其余由 DID 派生。
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

  /// 头像文字。
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

/// 对话列表中的一笔。
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

  /// 与 [peerDid] 相同，方便直接作为 key。
  final String peerDid;

  final String title;

  final String lastText;

  final int lastTsMs;

  final int unread;

  final MessageStatus? lastStatus;

  final bool pinned;

  /// 尚未送出的草稿。
  final String draft;

  /// 最后一则讯息的媒体种类（'image' / 'audio' / null），用于列表预览。
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

import 'package:flutter/foundation.dart' show immutable;

/// 一个群组聊天。
///
/// 群组以「共享对称金钥」做端到端加密：所有成员都用同一把 32 位元组 AES 金钥
/// 加密／解密群讯息，讯息发到群组专属的 Waku content topic。建立者产生金钥后，
/// 用每位成员的 X25519 公钥把它加密，透过一对一邀请封包分发给大家。
@immutable
class GroupChat {
  const GroupChat({
    required this.id,
    required this.name,
    required this.memberDids,
    required this.creatorDid,
    required this.keyB64,
    required this.createdAtMs,
    this.lastText = '',
    this.lastTsMs = 0,
    this.unread = 0,
    this.pinned = false,
    this.draft = '',
    this.lastMedia,
  });

  /// 群组唯一识别码（UUID）。
  final String id;

  /// 显示名称。
  final String name;

  /// 成员 DID（小写，含建立者与自己）。
  final List<String> memberDids;

  /// 建立者 DID。
  final String creatorDid;

  /// 群组共享对称金钥（原始 32 位元组，Base64）。本机已解密存放，
  /// 与讯息内容同级，不进一步加密。
  final String keyB64;

  final int createdAtMs;

  /// 最后一则讯息的文字（用于列表预览）。
  final String lastText;

  final int lastTsMs;

  final int unread;

  final bool pinned;

  /// 尚未送出的草稿。
  final String draft;

  /// 最后一则讯息的媒体种类（'image' / 'audio' / null）。
  final String? lastMedia;

  /// 会话列表用的稳定键（与 [id] 相同，方便直接作为 key）。
  String get peerKey => 'grp:$id';

  bool get isMember => memberDids.isNotEmpty;

  GroupChat copyWith({
    String? id,
    String? name,
    List<String>? memberDids,
    String? creatorDid,
    String? keyB64,
    int? createdAtMs,
    String? lastText,
    int? lastTsMs,
    int? unread,
    bool? pinned,
    String? draft,
    String? lastMedia,
  }) {
    return GroupChat(
      id: id ?? this.id,
      name: name ?? this.name,
      memberDids: memberDids ?? this.memberDids,
      creatorDid: creatorDid ?? this.creatorDid,
      keyB64: keyB64 ?? this.keyB64,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      lastText: lastText ?? this.lastText,
      lastTsMs: lastTsMs ?? this.lastTsMs,
      unread: unread ?? this.unread,
      pinned: pinned ?? this.pinned,
      draft: draft ?? this.draft,
      lastMedia: lastMedia ?? this.lastMedia,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'members': memberDids,
        'creator': creatorDid,
        'key': keyB64,
        'createdAt': createdAtMs,
        'lastText': lastText,
        'lastTsMs': lastTsMs,
        'unread': unread,
        'pinned': pinned,
        'draft': draft,
        if (lastMedia != null) 'lastMedia': lastMedia,
      };

  static GroupChat? fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return null;
    final id = json['id'];
    final key = json['key'];
    if (id is! String || key is! String) return null;
    final membersRaw = json['members'];
    final List<String> members = membersRaw is List
        ? membersRaw.map((e) => '$e'.toLowerCase()).toList()
        : <String>[];
    return GroupChat(
      id: id,
      name: (json['name'] as String?) ?? '',
      memberDids: members,
      creatorDid: (json['creator'] as String?)?.toLowerCase() ?? '',
      keyB64: key,
      createdAtMs: (json['createdAt'] as int?) ?? 0,
      lastText: (json['lastText'] as String?) ?? '',
      lastTsMs: (json['lastTsMs'] as int?) ?? 0,
      unread: (json['unread'] as int?) ?? 0,
      pinned: (json['pinned'] as bool?) ?? false,
      draft: (json['draft'] as String?) ?? '',
      lastMedia: json['lastMedia'] as String?,
    );
  }
}

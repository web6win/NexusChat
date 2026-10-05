import 'package:flutter/foundation.dart' show immutable;

/// 一個群組聊天。
///
/// 群組以「共享對稱金鑰」做端到端加密：所有成員都用同一把 32 位元組 AES 金鑰
/// 加密／解密群訊息，訊息發到群組專屬的 Waku content topic。建立者產生金鑰後，
/// 用每位成員的 X25519 公鑰把它加密，透過一對一邀請封包分發給大家。
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

  /// 群組唯一識別碼（UUID）。
  final String id;

  /// 顯示名稱。
  final String name;

  /// 成員 DID（小寫，含建立者與自己）。
  final List<String> memberDids;

  /// 建立者 DID。
  final String creatorDid;

  /// 群組共享對稱金鑰（原始 32 位元組，Base64）。本機已解密存放，
  /// 與訊息內容同級，不進一步加密。
  final String keyB64;

  final int createdAtMs;

  /// 最後一則訊息的文字（用於列表預覽）。
  final String lastText;

  final int lastTsMs;

  final int unread;

  final bool pinned;

  /// 尚未送出的草稿。
  final String draft;

  /// 最後一則訊息的媒體種類（'image' / 'audio' / null）。
  final String? lastMedia;

  /// 會話列表用的穩定鍵（與 [id] 相同，方便直接作為 key）。
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

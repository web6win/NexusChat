import '../crypto/app_identity.dart';
import '../models/app_settings.dart';
import '../models/chat_models.dart';
import '../models/identity_hint.dart';
import '../models/security_settings.dart';
import '../models/group_models.dart';
import '../security/vault.dart';
import '../storage/local_store.dart';

/// 设定档存取。
class SettingsRepository {
  SettingsRepository(this._store);

  final LocalStore _store;

  AppSettings load() {
    final raw = _store.read(LocalStore.kSettings);
    return AppSettings.fromJson(raw is Map ? raw : null);
  }

  Future<void> save(AppSettings settings) =>
      _store.write(LocalStore.kSettings, settings.toJson());
}

/// 安全设定存取（自动锁定时长等；不含秘密）。
class SecurityRepository {
  SecurityRepository(this._store);

  final LocalStore _store;

  SecuritySettings load() =>
      SecuritySettings.fromJson(_store.read(LocalStore.kSecurity));

  Future<void> save(SecuritySettings settings) =>
      _store.write(LocalStore.kSecurity, settings.toJson());
}

/// 身份存取。
///
/// 秘密材料（助记词 / 私钥 / 加密种子）一律以 [Vault] 加密后存放，
/// 明文永不落地。另外保存一份「公开提示」（did / address / 加密公钥），
/// 让锁定状态下仍能判断身份是否存在并显示帐户。
class IdentityRepository {
  IdentityRepository(this._store);

  final LocalStore _store;

  /// 是否已存在加密保险库。
  bool get hasVault =>
      Vault.looksLikeVault(_store.read(LocalStore.kIdentityVault));

  /// 加密保险库的原始密文（交给 [Vault.open] 解密）。
  Object? get vaultBlob => _store.read(LocalStore.kIdentityVault);

  /// 保险库的迭代次数（供 UI 显示目前强度）。
  int get vaultIterations =>
      Vault.iterationsOf(_store.read(LocalStore.kIdentityVault));

  /// 公开提示。
  IdentityHint? hint() =>
      IdentityHint.fromJson(_store.read(LocalStore.kIdentityHint));

  /// 是否仍存在旧版的「明文身份」，需要引导使用者设定密码完成迁移。
  bool get hasLegacyPlaintext => _store.read(LocalStore.kIdentity) is Map;

  /// 读取旧版明文身份（**仅供一次性迁移**，迁移后立刻删除）。
  AppIdentity? loadLegacy() {
    final raw = _store.read(LocalStore.kIdentity);
    if (raw is! Map) return null;
    try {
      return AppIdentity.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  /// 写入加密保险库，同时更新公开提示并**删除任何明文残留**。
  Future<void> saveVault(
    Map<String, dynamic> blob,
    AppIdentity identity,
  ) async {
    await _store.write(LocalStore.kIdentityVault, blob);
    await _store.write(LocalStore.kIdentityHint, identity.toHintJson());
    await _store.delete(LocalStore.kIdentity);
  }

  /// 只更新公开提示（例如身份卡片资讯变动）。
  Future<void> saveHint(AppIdentity identity) =>
      _store.write(LocalStore.kIdentityHint, identity.toHintJson());

  /// 清除全部身份资料（密文、提示与旧明文）。
  Future<void> clear() async {
    await _store.delete(LocalStore.kIdentityVault);
    await _store.delete(LocalStore.kIdentityHint);
    await _store.delete(LocalStore.kIdentity);
  }
}

/// 联络人存取。
class ContactsRepository {
  ContactsRepository(this._store);

  final LocalStore _store;

  List<Contact> all() {
    return _store
        .readPrefix(LocalStore.kContactPrefix)
        .map((raw) => raw is Map ? Contact.fromJson(raw) : null)
        .whereType<Contact>()
        .toList()
      ..sort((a, b) => (b.addedAtMs ?? 0).compareTo(a.addedAtMs ?? 0));
  }

  Future<void> save(Contact contact) =>
      _store.write('${LocalStore.kContactPrefix}${contact.did}', contact.toJson());

  Future<void> remove(String did) =>
      _store.delete('${LocalStore.kContactPrefix}$did');

  Future<void> clear() => _store.deletePrefix(LocalStore.kContactPrefix);
}

/// 对话存取。
class ConversationsRepository {
  ConversationsRepository(this._store);

  final LocalStore _store;

  List<Conversation> all() {
    final list = _store
        .readPrefix(LocalStore.kConversationPrefix)
        .map((raw) => raw is Map ? Conversation.fromJson(raw) : null)
        .whereType<Conversation>()
        .toList();
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.lastTsMs.compareTo(a.lastTsMs);
    });
    return list;
  }

  Future<void> save(Conversation conversation) => _store.write(
        '${LocalStore.kConversationPrefix}${conversation.peerDid}',
        conversation.toJson(),
      );

  Future<void> remove(String peerDid) =>
      _store.delete('${LocalStore.kConversationPrefix}$peerDid');

  Future<void> clear() => _store.deletePrefix(LocalStore.kConversationPrefix);
}

/// 讯息存取。
class MessagesRepository {
  MessagesRepository(this._store);

  final LocalStore _store;

  List<ChatMessage> all() {
    final list = _store
        .readPrefix(LocalStore.kMessagePrefix)
        .map((raw) => raw is Map ? ChatMessage.fromJson(raw) : null)
        .whereType<ChatMessage>()
        .toList();
    list.sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
    return list;
  }

  List<ChatMessage> forPeer(String peerDid) {
    return all().where((m) => m.peerDid == peerDid).toList();
  }

  Future<void> save(ChatMessage message) =>
      _store.write('${LocalStore.kMessagePrefix}${message.id}', message.toJson());

  Future<void> remove(String id) => _store.delete('${LocalStore.kMessagePrefix}$id');

  /// 标记某则讯息为「本机已删除」（墓碑）。
  ///
  /// 去中心化网路下讯息仍留在节点的 store 里，重开 App 的全量回溯会把它
  /// 拉回来；没有墓碑的话「删除」等于白删。
  Future<void> markDeleted(String id) => _store.write(
        '${LocalStore.kDeletedMessagePrefix}$id',
        DateTime.now().millisecondsSinceEpoch,
      );

  /// 某则讯息是否已被本机删除（见 [markDeleted]）。
  bool isDeleted(String id) =>
      _store.read('${LocalStore.kDeletedMessagePrefix}$id') != null;

  Future<void> removeByPeer(String peerDid) async {
    final targets = all().where((m) => m.peerDid == peerDid).toList();
    for (final message in targets) {
      await remove(message.id);
    }
  }

  Future<void> clear() => _store.deletePrefix(LocalStore.kMessagePrefix);
}

/// 群组聊天存取。
class GroupsRepository {
  GroupsRepository(this._store);

  final LocalStore _store;

  List<GroupChat> all() {
    final list = _store
        .readPrefix(LocalStore.kGroupPrefix)
        .map((raw) => raw is Map ? GroupChat.fromJson(raw) : null)
        .whereType<GroupChat>()
        .toList();
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.lastTsMs.compareTo(a.lastTsMs);
    });
    return list;
  }

  GroupChat? byId(String id) {
    final raw = _store.read('${LocalStore.kGroupPrefix}$id');
    return raw is Map ? GroupChat.fromJson(raw) : null;
  }

  Future<void> save(GroupChat group) =>
      _store.write('${LocalStore.kGroupPrefix}${group.id}', group.toJson());

  Future<void> remove(String id) =>
      _store.delete('${LocalStore.kGroupPrefix}$id');

  Future<void> clear() => _store.deletePrefix(LocalStore.kGroupPrefix);
}

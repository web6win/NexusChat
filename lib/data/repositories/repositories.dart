import '../crypto/app_identity.dart';
import '../models/app_settings.dart';
import '../models/chat_models.dart';
import '../models/identity_hint.dart';
import '../models/security_settings.dart';
import '../security/vault.dart';
import '../storage/local_store.dart';

/// 設定檔存取。
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

/// 安全設定存取（自動鎖定時長等；不含秘密）。
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
/// 秘密材料（助記詞 / 私鑰 / 加密種子）一律以 [Vault] 加密後存放，
/// 明文永不落地。另外保存一份「公開提示」（did / address / 加密公鑰），
/// 讓鎖定狀態下仍能判斷身份是否存在並顯示帳戶。
class IdentityRepository {
  IdentityRepository(this._store);

  final LocalStore _store;

  /// 是否已存在加密保險庫。
  bool get hasVault =>
      Vault.looksLikeVault(_store.read(LocalStore.kIdentityVault));

  /// 加密保險庫的原始密文（交給 [Vault.open] 解密）。
  Object? get vaultBlob => _store.read(LocalStore.kIdentityVault);

  /// 保險庫的迭代次數（供 UI 顯示目前強度）。
  int get vaultIterations =>
      Vault.iterationsOf(_store.read(LocalStore.kIdentityVault));

  /// 公開提示。
  IdentityHint? hint() =>
      IdentityHint.fromJson(_store.read(LocalStore.kIdentityHint));

  /// 是否仍存在舊版的「明文身份」，需要引導使用者設定密碼完成遷移。
  bool get hasLegacyPlaintext => _store.read(LocalStore.kIdentity) is Map;

  /// 讀取舊版明文身份（**僅供一次性遷移**，遷移後立刻刪除）。
  AppIdentity? loadLegacy() {
    final raw = _store.read(LocalStore.kIdentity);
    if (raw is! Map) return null;
    try {
      return AppIdentity.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  /// 寫入加密保險庫，同時更新公開提示並**刪除任何明文殘留**。
  Future<void> saveVault(
    Map<String, dynamic> blob,
    AppIdentity identity,
  ) async {
    await _store.write(LocalStore.kIdentityVault, blob);
    await _store.write(LocalStore.kIdentityHint, identity.toHintJson());
    await _store.delete(LocalStore.kIdentity);
  }

  /// 只更新公開提示（例如身份卡片資訊變動）。
  Future<void> saveHint(AppIdentity identity) =>
      _store.write(LocalStore.kIdentityHint, identity.toHintJson());

  /// 清除全部身份資料（密文、提示與舊明文）。
  Future<void> clear() async {
    await _store.delete(LocalStore.kIdentityVault);
    await _store.delete(LocalStore.kIdentityHint);
    await _store.delete(LocalStore.kIdentity);
  }
}

/// 聯絡人存取。
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

/// 對話存取。
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

/// 訊息存取。
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

  Future<void> removeByPeer(String peerDid) async {
    final targets = all().where((m) => m.peerDid == peerDid).toList();
    for (final message in targets) {
      await remove(message.id);
    }
  }

  Future<void> clear() => _store.deletePrefix(LocalStore.kMessagePrefix);
}

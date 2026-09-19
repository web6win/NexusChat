import '../data/crypto/app_identity.dart';
import '../data/crypto/crypto_service.dart';
import '../data/crypto/did.dart';
import '../data/models/app_settings.dart';
import '../data/models/chat_models.dart' show Contact;
import '../data/models/identity_hint.dart';
import '../data/models/security_settings.dart';
import '../data/repositories/repositories.dart';
import '../data/security/vault.dart';
import '../data/storage/local_store.dart';
import '../data/waku/nwaku_rest_transport.dart';
import '../data/waku/waku_service.dart';

/// 應用程式的核心容器：持有本地儲存、身份、密碼學服務與 Waku 連線。
///
/// ## 安全模型
///
/// 秘密材料（助記詞 / 私鑰 / 加密種子）以使用者密碼加密後存放，
/// **啟動時不解鎖** —— 只有在使用者輸入密碼後才會出現在記憶體中：
///
/// - 未建立身份：`hint == null && identity == null`
/// - 已建立但鎖定：`hint != null && identity == null`（記憶體中沒有秘密）
/// - 已解鎖：`identity != null`（才會有 [crypto] / [waku]）
///
/// 鎖定時會把 [identity]、[crypto]、[waku] 一律歸零並斷開連線，
/// 讓秘密物件不再被任何可達路徑引用。
class Core {
  Core._(this.store);

  final LocalStore store;

  /// 目前設定（由 [SettingsRepository] 載入，會被控制器寫回）。
  late AppSettings settings;

  /// 安全設定（自動鎖定等；不含秘密）。
  late SecuritySettings security;

  late final SettingsRepository settingsRepo = SettingsRepository(store);
  late final SecurityRepository securityRepo = SecurityRepository(store);
  late final IdentityRepository identityRepo = IdentityRepository(store);
  late final ContactsRepository contactsRepo = ContactsRepository(store);
  late final ConversationsRepository conversationsRepo =
      ConversationsRepository(store);
  late final MessagesRepository messagesRepo = MessagesRepository(store);

  /// 身份的公開提示（明文，鎖定時仍存在，用於顯示與路由）。
  IdentityHint? hint;

  /// 已解鎖的身份；鎖定時為 `null`。
  AppIdentity? identity;

  CryptoService? crypto;

  WakuService? waku;

  /// 本機是否存在身份（不論是否已解鎖）。
  bool get hasIdentity => hint != null || identityRepo.hasVault;

  /// 是否處於鎖定狀態（有身份但尚未輸入密碼）。
  bool get isLocked => hasIdentity && identity == null;

  /// 是否存在舊版明文身份，需要設定密碼完成遷移。
  bool get needsMigration => !hasIdentity && identityRepo.hasLegacyPlaintext;

  /// 保險庫密文是否結構正確可用。
  ///
  /// 正常流程下恆為 true；若為 false 代表本地資料毀損，只能重新建立身份。
  bool get vaultUsable => identityRepo.hasVault;

  /// 保險庫目前的 KDF 迭代次數（未加密時為預設值）。
  int get vaultIterations => identityRepo.hasVault
      ? identityRepo.vaultIterations
      : Vault.defaultIterations;

  /// 顯示用的簡短地址（鎖定時取公開提示）。
  String get accountAddress => identity?.address ?? hint?.address ?? '';

  String get did => identity?.did ?? '';

  /// 啟動流程：初始化儲存、載入設定與公開提示。
  ///
  /// **刻意不解鎖身份** —— 秘密要等使用者輸入密碼才會載入記憶體。
  static Future<Core> bootstrap() async {
    final store = LocalStore.instance;
    await store.init();
    final core = Core._(store);
    core.settings = core.settingsRepo.load();
    core.security = core.securityRepo.load();
    core.hint = core.identityRepo.hint();
    // 舊版本的本機模擬模式會寫入示範聯絡人；模式已移除，順手清掉殘留，
    // 避免使用者看到永遠不可能有金鑰的假聯絡人。
    await core.purgeDemoContacts();
    return core;
  }

  /// 刪除本機模擬時代遺留的示範聯絡人、對話與訊息。
  ///
  /// 只針對 `isDemo == true` 的資料，不影響真實聯絡人。
  Future<void> purgeDemoContacts() async {
    final demos = contactsRepo.all().where((c) => c.isDemo).toList();
    for (final contact in demos) {
      await messagesRepo.removeByPeer(contact.did);
      await conversationsRepo.remove(contact.did);
      await contactsRepo.remove(contact.did);
    }
  }

  // ------------------------------------------------------------ 建立 / 還原

  /// 建立全新身份（12 個助記詞）並以 [password] 加密保存。
  Future<AppIdentity> createIdentity({required String password}) async {
    final identity = await AppIdentity.generate();
    await _persist(identity, password);
    await _attach(identity);
    return identity;
  }

  /// 由助記詞還原身份並以 [password] 加密保存。
  Future<AppIdentity> restoreIdentity(
    String mnemonic, {
    required String password,
  }) async {
    final identity = await AppIdentity.fromMnemonic(mnemonic);
    await _persist(identity, password);
    await _attach(identity);
    return identity;
  }

  /// 由私鑰（hex）匯入身份並以 [password] 加密保存。
  ///
  /// 匯入後只有私鑰、沒有助記詞，因此無法用助記詞回復；[AppIdentity.hasMnemonic]
  /// 會是 false，UI 據此改為顯示私鑰備份。
  Future<AppIdentity> importPrivateKey(
    String privateHex, {
    required String password,
  }) async {
    final identity = await AppIdentity.fromPrivateKeyHex(privateHex);
    await _persist(identity, password);
    await _attach(identity);
    return identity;
  }

  /// 把舊版明文身份遷移進加密保險庫（一次性）。
  ///
  /// 成功後明文鍵會被刪除，[needsMigration] 隨之變為 false。
  Future<AppIdentity> migrateToVault(String password) async {
    final legacy = identityRepo.loadLegacy();
    if (legacy == null) {
      throw StateError('本機沒有可遷移的舊版身份');
    }
    await _persist(legacy, password);
    await _attach(legacy);
    return legacy;
  }

  // ------------------------------------------------------------ 鎖定 / 解鎖

  /// 以密碼解鎖身份，失敗時拋出 [VaultException]。
  Future<AppIdentity> unlock(String password) async {
    final payload = await Vault.open(
      blob: identityRepo.vaultBlob,
      password: password,
    );
    final identity = AppIdentity.fromSecretJson(payload);
    await _attach(identity);
    return identity;
  }

  /// 鎖定：清除記憶體中的秘密並斷開所有連線。
  ///
  /// Dart 的 `String` 不可變，無法真正抹除內容；但把 [identity]、[crypto]、
  /// [waku] 歸零可讓這些物件失去可達路徑、盡早被回收，同時立即停止
  /// 任何使用金鑰的後台活動（訊息解密、廣播）。
  Future<void> lock() async {
    final service = waku;
    waku = null;
    if (service != null) {
      try {
        await service.dispose();
      } catch (_) {
        // 斷線失敗不影響鎖定本身。
      }
    }
    crypto = null;
    identity = null;
  }

  /// 以目前密碼驗證後換成新密碼（會重新產生 salt）。
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    // 先驗證舊密碼：解不開就不動任何資料。
    final payload = await Vault.open(
      blob: identityRepo.vaultBlob,
      password: currentPassword,
    );
    await _persist(AppIdentity.fromSecretJson(payload), newPassword);
  }

  /// 驗證密碼是否正確（不改動狀態）。
  Future<bool> verifyPassword(String password) =>
      Vault.verify(blob: identityRepo.vaultBlob, password: password);

  // ------------------------------------------------------------ 內部

  /// 加密身份並寫入保險庫，同時更新公開提示。
  Future<void> _persist(AppIdentity identity, String password) async {
    final blob = await Vault.seal(
      payload: identity.toSecretJson(),
      password: password,
    );
    await identityRepo.saveVault(blob, identity);
    hint = IdentityHint.fromJson(identity.toHintJson());
  }

  /// 綁定身份並建立密碼學／Waku 服務。
  Future<void> _attach(AppIdentity value) async {
    identity = value;
    hint = IdentityHint.fromJson(value.toHintJson());
    crypto = await CryptoService.create(value);
    await applyTransport(settings.resolvedActiveNodeUrl);
  }

  /// 套用節點設定並（重新）建立 Waku 連線。
  ///
  /// 一次只連線一台節點：使用者選取的那一台（見
  /// `AppSettings.resolvedActiveNodeUrl`）。設定頁裡的節點清單只是候選池，
  /// 切換節點時會呼叫這裡重建連線；其他節點的線上狀態由節點探測器提供，
  /// 與實際連線無關。
  Future<void> applyTransport(String nodeUrl) async {
    final previous = waku;
    waku = null;
    if (previous != null) {
      try {
        await previous.dispose();
      } catch (_) {
        // 舊連線收尾失敗不影響新連線建立。
      }
    }

    final current = identity;
    if (current == null || crypto == null) return;

    final transport = NwakuRestTransport(baseUrl: nodeUrl);
    final service = WakuService(
      transport: transport,
      identity: current,
      crypto: crypto!,
    );
    waku = service;
    await service.start();
  }

  /// 廣播金鑰包（若尚未建立連線則略過）。
  Future<void> publishKeyBundleIfReady(String nickname) async {
    final service = waku;
    if (service == null) return;
    await service.publishKeyBundle(nickname: nickname);
  }

  /// 由 DID 建立聯絡人（沒有金鑰時僅先建立名片）。
  Future<Contact> addContactByDid(String did, {String? name, String? ens}) {
    final normalized = Did.isEthrDid(did) ? did : Did.fromAddress(did);
    final contact = Contact(
      did: normalized,
      name: name ?? Did.shortDid(normalized),
      ens: ens,
      addedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    return contactsRepo.save(contact).then((_) => contact);
  }

  Future<void> saveSettings(AppSettings value) async {
    settings = value;
    await settingsRepo.save(value);
  }

  Future<void> saveSecurity(SecuritySettings value) async {
    security = value;
    await securityRepo.save(value);
  }

  /// 清除本機身份與所有資料。
  Future<void> wipe() async {
    await lock();
    hint = null;
    await store.clearApp();
  }
}

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

/// 应用程式的核心容器：持有本地储存、身份、密码学服务与 Waku 连线。
///
/// ## 安全模型
///
/// 秘密材料（助记词 / 私钥 / 加密种子）以使用者密码加密后存放，
/// **启动时不解锁** —— 只有在使用者输入密码后才会出现在记忆体中：
///
/// - 未建立身份：`hint == null && identity == null`
/// - 已建立但锁定：`hint != null && identity == null`（记忆体中没有秘密）
/// - 已解锁：`identity != null`（才会有 [crypto] / [waku]）
///
/// 锁定时会把 [identity]、[crypto]、[waku] 一律归零并断开连线，
/// 让秘密物件不再被任何可达路径引用。
class Core {
  Core._(this.store);

  final LocalStore store;

  /// 目前设定（由 [SettingsRepository] 载入，会被控制器写回）。
  late AppSettings settings;

  /// 安全设定（自动锁定等；不含秘密）。
  late SecuritySettings security;

  late final SettingsRepository settingsRepo = SettingsRepository(store);
  late final SecurityRepository securityRepo = SecurityRepository(store);
  late final IdentityRepository identityRepo = IdentityRepository(store);
  late final ContactsRepository contactsRepo = ContactsRepository(store);
  late final ConversationsRepository conversationsRepo =
      ConversationsRepository(store);
  late final MessagesRepository messagesRepo = MessagesRepository(store);
  late final GroupsRepository groupsRepo = GroupsRepository(store);

  /// 身份的公开提示（明文，锁定时仍存在，用于显示与路由）。
  IdentityHint? hint;

  /// 已解锁的身份；锁定时为 `null`。
  AppIdentity? identity;

  CryptoService? crypto;

  WakuService? waku;

  /// 本机是否存在身份（不论是否已解锁）。
  bool get hasIdentity => hint != null || identityRepo.hasVault;

  /// 是否处于锁定状态（有身份但尚未输入密码）。
  bool get isLocked => hasIdentity && identity == null;

  /// 是否存在旧版明文身份，需要设定密码完成迁移。
  bool get needsMigration => !hasIdentity && identityRepo.hasLegacyPlaintext;

  /// 保险库密文是否结构正确可用。
  ///
  /// 正常流程下恒为 true；若为 false 代表本地资料毁损，只能重新建立身份。
  bool get vaultUsable => identityRepo.hasVault;

  /// 保险库目前的 KDF 迭代次数（未加密时为预设值）。
  int get vaultIterations => identityRepo.hasVault
      ? identityRepo.vaultIterations
      : Vault.defaultIterations;

  /// 显示用的简短地址（锁定时取公开提示）。
  String get accountAddress => identity?.address ?? hint?.address ?? '';

  String get did => identity?.did ?? '';

  /// 启动流程：初始化储存、载入设定与公开提示。
  ///
  /// **刻意不解锁身份** —— 秘密要等使用者输入密码才会载入记忆体。
  static Future<Core> bootstrap() async {
    final store = LocalStore.instance;
    await store.init();
    final core = Core._(store);
    core.settings = core.settingsRepo.load();
    core.security = core.securityRepo.load();
    core.hint = core.identityRepo.hint();
    // 旧版本的本机模拟模式会写入示范联络人；模式已移除，顺手清掉残留，
    // 避免使用者看到永远不可能有金钥的假联络人。
    await core.purgeDemoContacts();
    return core;
  }

  /// 删除本机模拟时代遗留的示范联络人、对话与讯息。
  ///
  /// 只针对 `isDemo == true` 的资料，不影响真实联络人。
  Future<void> purgeDemoContacts() async {
    final demos = contactsRepo.all().where((c) => c.isDemo).toList();
    for (final contact in demos) {
      await messagesRepo.removeByPeer(contact.did);
      await conversationsRepo.remove(contact.did);
      await contactsRepo.remove(contact.did);
    }
  }

  // ------------------------------------------------------------ 建立 / 还原

  /// 建立全新身份（12 个助记词）并以 [password] 加密保存。
  ///
  /// [passphrase] 为 BIP39 密码短语（可选）。
  Future<AppIdentity> createIdentity({
    required String password,
    String passphrase = '',
  }) async {
    final identity = await AppIdentity.generate(passphrase: passphrase);
    await _persist(identity, password);
    await _attach(identity);
    return identity;
  }

  /// 由助记词还原身份并以 [password] 加密保存。
  ///
  /// [passphrase] 为当初建立时使用的 BIP39 密码短语；打错不会报错，
  /// 只会还原出**另一个**身份，因此呼叫端应先让使用者核对地址。
  Future<AppIdentity> restoreIdentity(
    String mnemonic, {
    required String password,
    String passphrase = '',
  }) async {
    final identity =
        await AppIdentity.fromMnemonic(mnemonic, passphrase: passphrase);
    await _persist(identity, password);
    await _attach(identity);
    return identity;
  }

  /// 由私钥（hex）汇入身份并以 [password] 加密保存。
  ///
  /// 汇入后只有私钥、没有助记词，因此无法用助记词回复；[AppIdentity.hasMnemonic]
  /// 会是 false，UI 据此改为显示私钥备份。
  Future<AppIdentity> importPrivateKey(
    String privateHex, {
    required String password,
  }) async {
    final identity = await AppIdentity.fromPrivateKeyHex(privateHex);
    await _persist(identity, password);
    await _attach(identity);
    return identity;
  }

  /// 把旧版明文身份迁移进加密保险库（一次性）。
  ///
  /// 成功后明文键会被删除，[needsMigration] 随之变为 false。
  Future<AppIdentity> migrateToVault(String password) async {
    final legacy = identityRepo.loadLegacy();
    if (legacy == null) {
      throw StateError('本机没有可迁移的旧版身份');
    }
    await _persist(legacy, password);
    await _attach(legacy);
    return legacy;
  }

  // ------------------------------------------------------------ 锁定 / 解锁

  /// 以密码解锁身份，失败时抛出 [VaultException]。
  Future<AppIdentity> unlock(String password) async {
    final payload = await Vault.open(
      blob: identityRepo.vaultBlob,
      password: password,
    );
    final identity = AppIdentity.fromSecretJson(payload);
    await _attach(identity);
    return identity;
  }

  /// 锁定：清除记忆体中的秘密并断开所有连线。
  ///
  /// Dart 的 `String` 不可变，无法真正抹除内容；但把 [identity]、[crypto]、
  /// [waku] 归零可让这些物件失去可达路径、尽早被回收，同时立即停止
  /// 任何使用金钥的后台活动（讯息解密、广播）。
  Future<void> lock() async {
    final service = waku;
    waku = null;
    if (service != null) {
      try {
        await service.dispose();
      } catch (_) {
        // 断线失败不影响锁定本身。
      }
    }
    crypto = null;
    identity = null;
  }

  /// 以目前密码验证后换成新密码（会重新产生 salt）。
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    // 先验证旧密码：解不开就不动任何资料。
    final payload = await Vault.open(
      blob: identityRepo.vaultBlob,
      password: currentPassword,
    );
    await _persist(AppIdentity.fromSecretJson(payload), newPassword);
  }

  /// 验证密码是否正确（不改动状态）。
  Future<bool> verifyPassword(String password) =>
      Vault.verify(blob: identityRepo.vaultBlob, password: password);

  // ------------------------------------------------------------ 内部

  /// 加密身份并写入保险库，同时更新公开提示。
  Future<void> _persist(AppIdentity identity, String password) async {
    final blob = await Vault.seal(
      payload: identity.toSecretJson(),
      password: password,
    );
    await identityRepo.saveVault(blob, identity);
    hint = IdentityHint.fromJson(identity.toHintJson());
  }

  /// 绑定身份并建立密码学／Waku 服务。
  Future<void> _attach(AppIdentity value) async {
    identity = value;
    hint = IdentityHint.fromJson(value.toHintJson());
    crypto = await CryptoService.create(value);
    await applyTransport(settings.resolvedActiveNodeUrl);
  }

  /// 套用节点设定并（重新）建立 Waku 连线。
  ///
  /// 一次只连线一台节点：使用者选取的那一台（见
  /// `AppSettings.resolvedActiveNodeUrl`）。设定页里的节点清单只是候选池，
  /// 切换节点时会呼叫这里重建连线；其他节点的线上状态由节点探测器提供，
  /// 与实际连线无关。
  Future<void> applyTransport(String nodeUrl) async {
    final previous = waku;
    waku = null;
    if (previous != null) {
      try {
        await previous.dispose();
      } catch (_) {
        // 旧连线收尾失败不影响新连线建立。
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

  /// 广播金钥包（若尚未建立连线则略过）。
  Future<void> publishKeyBundleIfReady(String nickname) async {
    final service = waku;
    if (service == null) return;
    await service.publishKeyBundle(nickname: nickname);
  }

  /// 由 DID 建立联络人（没有金钥时仅先建立名片）。
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

  /// 清除本机身份与所有资料。
  Future<void> wipe() async {
    await lock();
    hint = null;
    await store.clearApp();
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueNotifier, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../app/core.dart';
import '../data/crypto/app_identity.dart';
import '../data/crypto/crypto_service.dart';
import '../data/crypto/did.dart';
import '../data/ethereum/ethereum_service.dart';
import '../data/ethereum/tron_service.dart';
import '../data/ethereum/tx_service.dart';
import '../data/ethereum/chain_account.dart';
import '../data/models/app_settings.dart';
import '../data/models/chain.dart';
import '../data/models/token_def.dart';
import '../data/tokens/token_tx_history.dart';
import '../data/models/chat_models.dart';
import '../data/models/group_models.dart';
import '../data/models/security_settings.dart';
import '../data/security/vault.dart';
import '../data/waku/content_topics.dart';
import '../data/waku/envelope.dart';
import '../data/waku/message_content.dart';
import '../data/waku/node_probe.dart';
import '../data/waku/waku_message.dart';
import '../data/waku/waku_service.dart';
import '../data/waku/waku_transport.dart';
import '../data/media/media_size.dart';
import '../core/l10n/app_locale.dart';

/// 身份发生变化时递增，让路由重新判断导向。
final ValueNotifier<int> sessionVersion = ValueNotifier<int>(0);

/// 核心容器（在 main 中以 override 注入）。
final coreProvider = Provider<Core>((ref) {
  throw UnimplementedError('coreProvider 必须在 main() 中以 overrideWithValue 注入');
});

// ==========================================================================
// 设定
// ==========================================================================

/// 全站设定控制器。
final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(coreProvider).settings;

  Core get _core => ref.read(coreProvider);

  Future<void> _persist(AppSettings next) async {
    state = next;
    await _core.saveSettings(next);
  }

  Future<void> setTheme(ThemePreference theme) =>
      _persist(state.copyWith(theme: theme));

  Future<void> setLocaleCode(String code) =>
      _persist(state.copyWith(localeCode: code));

  /// 覆写整份节点清单（内建节点会被强制保留在最前面）。
  ///
  /// 若目前使用中的节点刚好被移除，会自动退回清单中的第一台，避免连线
  /// 指向已不存在的节点。
  Future<void> setNodeUrls(List<String> urls) async {
    final normalized = <String>[
      ...AppSettings.builtinNodeUrls,
      ...urls
          .map(AppSettings.normalizeNodeUrl)
          .where((u) => u.isNotEmpty && !AppSettings.isBuiltinNode(u)),
    ];
    final active = normalized.contains(state.activeNodeUrl)
        ? state.activeNodeUrl
        : normalized.first;
    await _persist(
      state.copyWith(nodeUrls: normalized, activeNodeUrl: active),
    );
    await _reconnect();
  }

  /// 新增自订节点。回传错误码（null 代表成功）。
  Future<String?> addNode(String raw) async {
    final url = AppSettings.normalizeNodeUrl(raw);
    if (url.isEmpty) return 'invalid';
    if (state.nodeUrls.contains(url)) return 'duplicate';
    await setNodeUrls(<String>[...state.nodeUrls, url]);
    return null;
  }

  /// 移除自订节点（内建节点不可移除）。
  Future<void> removeNode(String url) async {
    if (AppSettings.isBuiltinNode(url)) return;
    await setNodeUrls(
      state.nodeUrls.where((u) => u != url).toList(growable: false),
    );
  }

  /// 还原成预设节点（仅保留内建节点）。
  Future<void> resetNodes() => setNodeUrls(const <String>[]);

  /// 切换目前使用中的节点。
  ///
  /// 这是唯一会被连线的节点，因此切换后会立刻重建连线并重新同步。
  Future<void> setActiveNode(String url) async {
    if (!state.nodeUrls.contains(url) || state.activeNodeUrl == url) return;
    await _persist(state.copyWith(activeNodeUrl: url));
    await _reconnect();
  }

  /// 节点清单或使用中节点变更后，重建连线并重新同步。
  Future<void> _reconnect() async {
    await _core.applyTransport(state.resolvedActiveNodeUrl);
    ref.invalidate(networkStatusProvider);
    ref.invalidate(nodeStatusProvider);
    ref.read(chatControllerProvider.notifier).resetSync();
    await ref.read(chatControllerProvider.notifier).sync();
  }

  /// 切换钱包显示的区块链（仅影响钱包页，不影响聊天身份 did:ethr）。
  Future<void> setChain(ChainType chain) =>
      _persist(state.copyWith(chain: chain));

  /// 依链设定对应的 RPC / API 端点；留空则还原成该链的预设值。
  Future<void> setRpcFor(ChainType chain, String url) =>
      _persist(state.withRpc(chain, url));

  Future<void> setNickname(String nickname) =>
      _persist(state.copyWith(nickname: nickname));

  Future<void> setOnboarded(bool value) =>
      _persist(state.copyWith(onboarded: value));
}

/// 目前语系（空字串代表跟随系统）。
final localeProvider = Provider<AppLocale?>((ref) {
  final code = ref.watch(settingsProvider).localeCode;
  if (code.isEmpty) return null;
  return AppLocale.fromCode(code);
});

// ==========================================================================
// 身份
// ==========================================================================

/// 身份状态。
class SessionState {
  const SessionState({
    this.identity,
    this.busy = false,
    this.error,
    this.locked = false,
    this.needsMigration = false,
  });

  final AppIdentity? identity;
  final bool busy;
  final String? error;

  /// 本机已有身份，但尚未输入密码解锁（记忆体中没有任何秘密）。
  final bool locked;

  /// 存在旧版明文身份，需要设定密码完成迁移。
  final bool needsMigration;

  /// 已解锁。
  bool get hasIdentity => identity != null;

  SessionState copyWith({
    AppIdentity? identity,
    bool? busy,
    String? error,
    bool clearError = false,
    bool? locked,
    bool? needsMigration,
  }) {
    return SessionState(
      identity: identity ?? this.identity,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
      locked: locked ?? this.locked,
      needsMigration: needsMigration ?? this.needsMigration,
    );
  }
}

/// 身份控制器：建立、汇入、解锁、锁定、删除。
///
/// 同时负责**闲置自动锁定**：任何使用者互动都会重置计时器，
/// 逾时后呼叫 [lock] 把秘密清出记忆体。
final sessionProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

class SessionController extends Notifier<SessionState> {
  Timer? _idleTimer;
  DateTime? _lastActivity;

  /// 互动节流视窗：避免每次滑鼠移动都重建计时器。
  static const Duration _activityThrottle = Duration(seconds: 10);

  @override
  SessionState build() {
    ref.onDispose(_cancelIdleTimer);
    final core = ref.read(coreProvider);
    return SessionState(
      identity: core.identity,
      locked: core.isLocked,
      needsMigration: core.needsMigration,
    );
  }

  Core get _core => ref.read(coreProvider);

  // ------------------------------------------------------------ 建立 / 汇入

  /// 建立身份并立即以 [password] 加密保存。
  ///
  /// [passphrase] 为 BIP39 密码短语（可选，留空表示不使用）。
  ///
  /// 回传错误代码（`create-failed`）或 `null` 表示成功。
  Future<String?> createIdentity({
    required String password,
    String passphrase = '',
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final identity = await _core.createIdentity(
        password: password,
        passphrase: passphrase,
      );
      await _afterIdentity(identity, nickname: '');
      return null;
    } catch (_) {
      state = state.copyWith(busy: false, error: 'create-failed');
      return 'create-failed';
    }
  }

  /// 由助记词还原身份；错误代码 `invalid-mnemonic` / `restore-failed`。
  ///
  /// [passphrase] 为 BIP39 密码短语。注意它没有「对错」可言：任何字串都能
  /// 派生出一组身份，所以打错只会得到另一个钱包，不会抛错。
  Future<String?> restoreIdentity(
    String mnemonic, {
    required String password,
    String passphrase = '',
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final identity = await _core.restoreIdentity(
        mnemonic,
        password: password,
        passphrase: passphrase,
      );
      await _afterIdentity(
        identity,
        nickname: ref.read(settingsProvider).nickname,
      );
      return null;
    } on FormatException {
      state = state.copyWith(busy: false, error: 'invalid-mnemonic');
      return 'invalid-mnemonic';
    } catch (_) {
      state = state.copyWith(busy: false, error: 'restore-failed');
      return 'restore-failed';
    }
  }

  /// 由私钥汇入身份；失败时回传 null 并把错误代码写进 state。
  ///
  /// 错误代码：`invalid-private-key`（格式 / 范围不合法）、`import-failed`。
  Future<String?> importPrivateKey(
    String privateHex, {
    required String password,
  }) async {
    // 先做本地格式检查，让 UI 能给出精确的错误提示。
    if (!AppIdentity.isValidPrivateKey(privateHex)) {
      state = state.copyWith(busy: false, error: 'invalid-private-key');
      return 'invalid-private-key';
    }
    state = state.copyWith(busy: true, clearError: true);
    try {
      final identity = await _core.importPrivateKey(
        privateHex,
        password: password,
      );
      await _afterIdentity(
        identity,
        nickname: ref.read(settingsProvider).nickname,
      );
      return null;
    } catch (_) {
      state = state.copyWith(busy: false, error: 'import-failed');
      return 'import-failed';
    }
  }

  /// 把旧版明文身份迁移进加密保险库；错误代码 `migrate-failed`。
  Future<String?> migrateToVault(String password) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final identity = await _core.migrateToVault(password);
      await _afterIdentity(
        identity,
        nickname: ref.read(settingsProvider).nickname,
      );
      return null;
    } catch (_) {
      state = state.copyWith(busy: false, error: 'migrate-failed');
      return 'migrate-failed';
    }
  }

  // ------------------------------------------------------------ 解锁 / 锁定

  /// 以密码解锁。回传错误代码或 `null`。
  ///
  /// 错误代码：`bad-password`（密码错或密文毁损）、`unlock-failed`。
  ///
  /// 「解密成功」就等于「解锁成功」：之后的连线、金钥广播与同步都是副作用，
  /// 必须与解锁结果脱钩。否则节点连不上时会被回报成密码错误 ——
  /// 使用者输入的密码明明正确，却永远卡在锁屏。
  Future<String?> unlock(String password) async {
    state = state.copyWith(busy: true, clearError: true);

    AppIdentity identity;
    try {
      identity = await _core.unlock(password);
    } on VaultException catch (error) {
      state = state.copyWith(busy: false, error: error.code);
      return error.code;
    } catch (_) {
      state = state.copyWith(busy: false, error: 'unlock-failed');
      return 'unlock-failed';
    }

    try {
      await _afterIdentity(
        identity,
        nickname: ref.read(settingsProvider).nickname,
      );
    } catch (error, stackTrace) {
      // 连线类失败不推翻已成立的解锁；下一轮同步会自己补回来。
      debugPrint('post-unlock setup failed: $error\n$stackTrace');
      state = SessionState(identity: identity);
    }
    // 通知路由重新评估：解锁后才允许离开锁屏。
    sessionVersion.value++;
    _restartIdleTimer();
    return null;
  }

  /// 立即锁定：清空秘密、断开连线、回到锁屏。
  Future<void> lock() async {
    _cancelIdleTimer();
    _lastActivity = null;
    await _stopChat();
    await _core.lock();
    sessionVersion.value++;
    state = SessionState(locked: _core.hasIdentity);
    ref.invalidate(contactsProvider);
    ref.invalidate(networkStatusProvider);
  }

  /// 记录一次使用者互动，用来延后自动锁定。
  ///
  /// 以 10 秒节流，避免高频事件（滑鼠移动）造成多余的计时器重建。
  void noteActivity() {
    if (!state.hasIdentity) return;
    final now = DateTime.now();
    final last = _lastActivity;
    if (last != null && now.difference(last) < _activityThrottle) return;
    _lastActivity = now;
    _restartIdleTimer();
  }

  /// 页面切到背景时呼叫（仅在开启 lockOnHide 时生效）。
  Future<void> onAppHidden() async {
    if (!_core.security.lockOnHide) return;
    if (!state.hasIdentity) return;
    await lock();
  }

  Future<void> _stopChat() async {
    try {
      await ref.read(chatControllerProvider.notifier).stop();
    } catch (_) {
      // 尚未建立连线时不需处理。
    }
  }

  void _restartIdleTimer() {
    _cancelIdleTimer();
    final duration = _core.security.autoLockDuration;
    if (duration == null) return;
    _idleTimer = Timer(duration, () {
      // 只有仍处于解锁状态才需要锁定。
      if (state.hasIdentity) lock();
    });
  }

  void _cancelIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  /// 绑定新身份：建立连线、广播金钥包并开始同步。
  ///
  /// 只有「建立连线」与「写入状态」是必要的；广播与同步仰赖节点，
  /// 节点不可用时只记录，不让它回头推翻建立 / 解锁的结果。
  Future<void> _afterIdentity(AppIdentity identity, {String? nickname}) async {
    await _core.applyTransport(
      ref.read(settingsProvider).resolvedActiveNodeUrl,
    );
    state = SessionState(identity: identity);
    ref.invalidate(contactsProvider);
    ref.invalidate(networkStatusProvider);
    if (nickname != null && nickname.isNotEmpty) {
      await _bestEffort(() => _core.publishKeyBundleIfReady(nickname));
    }
    await _bestEffort(() => ref.read(chatControllerProvider.notifier).sync());
  }

  /// 执行需要网路的动作；失败只记录，不往上抛。
  Future<void> _bestEffort(Future<void> Function() action) async {
    try {
      await action();
    } catch (error, stackTrace) {
      debugPrint('network step failed: $error\n$stackTrace');
    }
  }

  /// 擦除本机所有资料（身份、讯息、联络人）。
  Future<void> wipeIdentity() async {
    _cancelIdleTimer();
    _lastActivity = null;
    await _stopChat();
    await _core.wipe();
    sessionVersion.value++;
    state = const SessionState();
    ref.invalidate(contactsProvider);
    ref.invalidate(chatControllerProvider);
    ref.invalidate(networkStatusProvider);
  }
}

// ==========================================================================
// 安全设定
// ==========================================================================

/// 安全设定控制器（自动锁定时长等）。
final securityProvider =
    NotifierProvider<SecurityController, SecuritySettings>(
  SecurityController.new,
);

class SecurityController extends Notifier<SecuritySettings> {
  @override
  SecuritySettings build() => ref.read(coreProvider).security;

  Core get _core => ref.read(coreProvider);

  Future<void> _persist(SecuritySettings next) async {
    state = next;
    await _core.saveSecurity(next);
    // 让闲置计时器立即套用新设定。
    ref.read(sessionProvider.notifier).noteActivity();
  }

  Future<void> setAutoLockMinutes(int minutes) =>
      _persist(state.copyWith(autoLockMinutes: minutes));

  Future<void> setLockOnHide(bool value) =>
      _persist(state.copyWith(lockOnHide: value));

  Future<void> setHideSecretsAfterSeconds(int seconds) =>
      _persist(state.copyWith(hideSecretsAfterSeconds: seconds));
}

// ==========================================================================
// 联络人
// ==========================================================================

/// 联络人控制器。
final contactsProvider =
    NotifierProvider<ContactsController, List<Contact>>(ContactsController.new);

class ContactsController extends Notifier<List<Contact>> {
  @override
  List<Contact> build() => ref.read(coreProvider).contactsRepo.all();

  Core get _core => ref.read(coreProvider);

  /// 由 DID / 地址 / ENS 加入联络人。回传错误码字串（null 代表成功）。
  Future<String?> add(String input, {String? nickname}) async {
    final value = input.trim();
    if (value.isEmpty) return 'invalid';

    String did;
    String? ens;
    String? resolvedAddress;

    if (Did.isEthrDid(value)) {
      did = value.toLowerCase();
    } else if (Did.isAddress(value)) {
      did = Did.fromAddress(value);
    } else if (Did.isEnsName(value)) {
      ens = value.toLowerCase();
      // ENS 只在以太坊主网存在，因此固定用以太坊的端点解析。
      final service = EthereumService(
        rpcUrl: ref.read(settingsProvider).rpcFor(ChainType.ethereum),
      );
      try {
        resolvedAddress = await service.resolveEns(ens);
      } finally {
        service.dispose();
      }
      if (resolvedAddress == null) return 'ens-failed';
      did = Did.fromAddress(resolvedAddress);
    } else {
      return 'invalid';
    }

    final existing = state.where((c) => c.did.toLowerCase() == did).toList();
    final contact = Contact(
      did: did,
      name: nickname ?? (existing.isNotEmpty ? existing.first.name : Did.shortDid(did)),
      ens: ens ?? (existing.isNotEmpty ? existing.first.ens : null),
      encPublicKeyB64: existing.isNotEmpty ? existing.first.encPublicKeyB64 : null,
      addedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _core.contactsRepo.save(contact);
    await refresh();
    unawaited(refreshKeys());
    return null;
  }

  Future<void> rename(String did, String name) async {
    final contact = state.firstWhere(
      (c) => c.did == did,
      orElse: () => Contact(did: did, name: name),
    );
    await _core.contactsRepo.save(contact.copyWith(name: name));
    await refresh();
  }

  Future<void> remove(String did) async {
    await _core.contactsRepo.remove(did);
    await refresh();
  }

  Future<void> refresh() async {
    state = _core.contactsRepo.all();
  }

  /// 从 Waku 的金钥包频道补齐联络人的加密公钥。
  ///
  /// 回传 `true` 表示有成功写入（或更新）至少一个联络人的公钥；
  /// `false` 表示没有变化或发生错误。回传值主要给 UI 做 snackbar 回馈。
  Future<bool> refreshKeys() async {
    final waku = _core.waku;
    if (waku == null) return false;
    try {
      final messages = await waku.fetch(<String>[ContentTopics.keyBundle]);
      var changed = false;
      for (final message in messages) {
        final updated = _applyKeyBundle(message);
        if (updated) changed = true;
      }
      if (changed) await refresh();
      return changed;
    } catch (error, stackTrace) {
      // 金钥包是非必要资料，不能让同步错误炸掉整个页面；
      // 但开发/测试阶段要把错误印出来，否则「同步中」会永远查不到原因。
      debugPrint('refreshKeys failed: $error\n$stackTrace');
      return false;
    }
  }

  bool _applyKeyBundle(WakuMessage message) {
    final envelope = NexusChatEnvelope.decodeBase64(message.payloadBase64);
    if (envelope == null) return false;
    if (envelope.type != EnvelopeType.keyBundle) return false;
    final pub = envelope.publicData;
    if (pub == null) return false;
    final did = (pub['did'] as String?)?.toLowerCase();
    final enc = pub['enc'] as String?;
    if (did == null || enc == null) return false;

    final index = state.indexWhere((c) => c.did.toLowerCase() == did);
    if (index < 0) return false;
    final contact = state[index];
    if (contact.encPublicKeyB64 == enc) return false;
    final updated = contact.copyWith(
      encPublicKeyB64: enc,
      name: (pub['name'] as String?)?.isNotEmpty == true
          ? pub['name'] as String
          : contact.name,
    );
    _core.contactsRepo.save(updated);
    return true;
  }
}

// ==========================================================================
// 网路状态
// ==========================================================================

/// 传输层健康状态。
final networkStatusProvider =
    FutureProvider<TransportHealth>((ref) async {
  final core = ref.watch(coreProvider);
  final waku = core.waku;
  if (waku == null) return const TransportHealth(ok: false, detail: 'no-identity');
  return waku.health();
});

/// 探测节点清单中的每一台（设定页显示节点状态）。
///
/// 实际连线只有使用中的那一台，但这里一律探测**整份节点清单**，使用者才能
/// 在切换前就看到哪一台可用。探测只发 `/health`，不会影响目前连线；
/// 用完即释放暂时建立的 HTTP 连线。
final nodeStatusProvider = FutureProvider<List<NodeStatus>>((ref) async {
  final urls = ref.watch(settingsProvider).nodeUrls;
  if (urls.isEmpty) return const <NodeStatus>[];
  final probe = NodeProbe(urls);
  try {
    return await probe.probeAll();
  } finally {
    probe.dispose();
  }
});

// ==========================================================================
// 聊天
// ==========================================================================

/// 聊天画面状态。
class ChatState {
  const ChatState({
    this.conversations = const <Conversation>[],
    this.groups = const <GroupChat>[],
    this.messages = const <String, List<ChatMessage>>{},
    this.loading = false,
  });

  final List<Conversation> conversations;
  final List<GroupChat> groups;
  final Map<String, List<ChatMessage>> messages;
  final bool loading;

  ChatState copyWith({
    List<Conversation>? conversations,
    List<GroupChat>? groups,
    Map<String, List<ChatMessage>>? messages,
    bool? loading,
  }) {
    return ChatState(
      conversations: conversations ?? this.conversations,
      groups: groups ?? this.groups,
      messages: messages ?? this.messages,
      loading: loading ?? this.loading,
    );
  }

  List<ChatMessage> forPeer(String peerDid) =>
      messages[peerDid] ?? const <ChatMessage>[];

  /// 由会话键（`grp:<id>`）找出群组。
  GroupChat? groupByPeerKey(String peerKey) {
    if (!peerKey.startsWith('grp:')) return null;
    final id = peerKey.substring(4);
    for (final group in groups) {
      if (group.id == id) return group;
    }
    return null;
  }
}

/// 聊天控制器：负责同步 Waku、收发讯息与维护对话列表。
final chatControllerProvider =
    NotifierProvider<ChatController, ChatState>(ChatController.new);

class ChatController extends Notifier<ChatState> {
  Timer? _timer;
  final Set<String> _seen = <String>{};

  /// 撤回通知先到、原始讯息还没到的情况：先把目标 ID 记下来，
  /// 等讯息真正进来时直接标成已撤回，避免「撤了又冒出来」。
  final Map<String, int> _pendingRecalls = <String, int>{};
  bool _syncing = false;
  DateTime? _lastKeyPublish;

  /// 上次把同步错误写进 console 的时间；用来节流，避免每 1.2 秒洗版。
  DateTime? _lastSyncErrorLog;

  /// 轮询间隔。讯息实际上是靠节点的 filter 推播，这里只是去取快取，
  /// 所以可以拉得很密；较重的 store / relay 查询由传输层自行节流。
  static const _pollInterval = Duration(milliseconds: 1200);
  static const _keyRepublishInterval = Duration(minutes: 2);

  /// 单则媒体的最大体积（位元组）。由网路端的 payload 预算反推，
  /// 见 [kMaxMediaBytes]（lib/data/media/media_size.dart）。

  @override
  ChatState build() {
    final core = ref.read(coreProvider);
    final conversations = core.conversationsRepo.all();
    final groups = core.groupsRepo.all();
    final all = core.messagesRepo.all();
    final grouped = <String, List<ChatMessage>>{};
    for (final message in all) {
      grouped.putIfAbsent(message.peerDid, () => <ChatMessage>[]).add(message);
    }
    for (final key in grouped.keys) {
      _seen.addAll(grouped[key]!.map((m) => m.id));
    }
    return ChatState(
      conversations: conversations,
      groups: groups,
      messages: grouped,
    );
  }

  Core get _core => ref.read(coreProvider);

  /// 启动轮询（由壳层呼叫）。
  ///
  /// 第一轮一定是全量回溯（[full] = true）：增量同步只会看上次同步之后的
  /// 讯息，若之前因为「对方不在联络人清单」等原因漏接，重开才补得回来。
  Future<void> start() async {
    await sync(full: true);
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) => sync());
  }

  /// 手动重新拉取：清掉同步时间戳记后跑一次全量回溯。
  Future<void> resyncHistory() async {
    resetSync();
    await sync(full: true);
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  void resetSync() {
    _core.saveSettings(_core.settings.copyWith(lastSyncMs: 0));
  }

  /// 拉取新讯息并解密。
  Future<void> sync({bool full = false}) async {
    final waku = _core.waku;
    if (waku == null || _syncing) return;
    _syncing = true;
    try {
      // 定期重发金钥包：刚加的联络人、或错过首次广播的客户端，都能靠
      // store 补到公钥。
      await _maybeRepublishKeys(waku);
      final contacts = ref.read(contactsProvider);
      // 轮询对象 = 联络人 + 已经有对话的对象；收件匣与金钥包频道由
      // topicsFor 自动带入，所以「对方加了我、我还没加对方」也收得到。
      final peers = <String>{
        ...contacts.map((c) => c.did),
        ...state.conversations.map((c) => c.peerDid),
        ...state.messages.keys,
      };
      final topics = <String>{
        ...waku.topicsFor(peers),
        ...waku.topicsForGroups(state.groups),
      }.toList(growable: false);
      // 先确保节点已把这些频道推播给我们：之后每轮只是去取节点收好的快取，
      // 不需要等下一轮才有机会命中，达到即时接收。
      await waku.subscribe(topics);
      final since = _core.settings.lastSyncMs;
      final messages = await waku.fetch(
        topics,
        // full = true 时不带时间过滤，让传输层用预设的 48 小时视窗回溯
        sinceMs: full ? null : (since > 0 ? since - 2000 : null),
      );
      var changed = false;
      for (final message in messages) {
        if (await _handleMessage(message)) changed = true;
      }
      await _core.saveSettings(
        _core.settings.copyWith(
          lastSyncMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      if (changed) _reload();
    } catch (error, stackTrace) {
      // 网路错误保留既有画面，等下一次轮询；但要把原因印出来（节流），
      // 否则「联络人一直同步中」这种问题会完全查不到线索。
      final now = DateTime.now();
      final last = _lastSyncErrorLog;
      if (last == null || now.difference(last) > const Duration(seconds: 20)) {
        _lastSyncErrorLog = now;
        debugPrint('sync failed: $error\n$stackTrace');
      }
    } finally {
      _syncing = false;
    }
  }

  Future<void> _maybeRepublishKeys(WakuService waku) async {
    final now = DateTime.now();
    final last = _lastKeyPublish;
    if (last != null && now.difference(last) < _keyRepublishInterval) {
      return;
    }
    _lastKeyPublish = now;
    try {
      await waku.publishKeyBundle(nickname: _core.settings.nickname);
    } catch (_) {
      // 节点暂时不可用（例如还没连上任何 peer），等下一轮再试
    }
  }

  Future<bool> _handleMessage(WakuMessage message) async {
    final waku = _core.waku;
    if (waku == null) return false;
    final envelope = NexusChatEnvelope.decodeBase64(message.payloadBase64);
    if (envelope == null) return false;
    if (_seen.contains(envelope.id)) return false;
    // 本机已删除的讯息：节点 store 里还有，重开后的全量回溯不能把它救回来。
    if (_core.messagesRepo.isDeleted(envelope.id)) return false;

    if (envelope.type == EnvelopeType.keyBundle) {
      _seen.add(envelope.id);
      final ok = _applyIncomingKeyBundle(envelope);
      if (ok) {
        await ref.read(contactsProvider.notifier).refresh();
        return true;
      }
      return false;
    }
    if (envelope.type == EnvelopeType.recall) {
      _seen.add(envelope.id);
      return _applyIncomingRecall(envelope);
    }
    if (envelope.type == EnvelopeType.groupInvite) {
      _seen.add(envelope.id);
      return _applyIncomingGroupInvite(envelope);
    }
    if (envelope.type != EnvelopeType.chat) return false;

    final myDid = _core.did;
    final to = envelope.to;
    final isGroup = to.startsWith('grp:');
    final outgoing = envelope.from.toLowerCase() == myDid.toLowerCase();
    final peerDid = isGroup ? to : (outgoing ? to : envelope.from);
    if (peerDid.isEmpty || peerDid == '*') return false;

    final String? plaintext;
    final String? senderDid;
    if (isGroup) {
      final group = state.groupByPeerKey(peerDid);
      if (group == null) return false;
      final opened = await waku.sealer.openGroup(
        envelope,
        base64Decode(group.keyB64),
      );
      if (opened == null) return false;
      plaintext = opened.plaintext;
      senderDid = envelope.from;
    } else {
      final opened = await waku.sealer.open(envelope);
      if (opened == null) return false;
      plaintext = opened.plaintext;
      senderDid = null;
    }
    final content = MessageContent.decode(plaintext ?? '');
    if (content.kind == MediaKind.text && content.text.isEmpty) return false;
    _seen.add(envelope.id);

    // 第一次收到某人讯息时自动建立名片：对方不需要事先加你为联络人，
    // 你这边也不会因为没加他而看不到人。（群组成员不在此列，名称走通讯录解析）
    if (!outgoing && !isGroup) await _ensureContact(peerDid, envelope);

    final chatMessage = ChatMessage(
      id: envelope.id,
      peerDid: peerDid,
      text: content.text,
      timestampMs: envelope.timestampMs,
      outgoing: outgoing,
      status: outgoing ? MessageStatus.sent : MessageStatus.delivered,
      kind: content.kind,
      mediaB64:
          content.mediaBytes == null ? null : base64Encode(content.mediaBytes!),
      mediaMime: content.mediaMime,
      mediaDurationMs: content.mediaDurationMs,
      mediaName: content.mediaName,
      senderDid: senderDid,
      // 撤回通知比原始讯息先到时，这里直接补上撤回标记。
      recalledAtMs: _pendingRecalls.remove(envelope.id),
    );
    await _core.messagesRepo.save(chatMessage);
    if (isGroup) {
      await _upsertGroupConversation(peerDid, chatMessage,
          incrementUnread: !outgoing);
    } else {
      await _upsertConversation(peerDid, chatMessage, incrementUnread: !outgoing);
    }
    return true;
  }

  /// 确保某个 DID 在通讯录里；若封包带有对方的加密公钥则一并写入，
  /// 这样马上就能回复，不必等下一次金钥包广播。
  Future<void> _ensureContact(String peerDid, NexusChatEnvelope envelope) async {
    final publicData = envelope.publicData;
    final enc = publicData?['enc'] as String?;
    final name = publicData?['name'] as String?;
    final contacts = ref.read(contactsProvider);
    final index =
        contacts.indexWhere((c) => c.did.toLowerCase() == peerDid.toLowerCase());

    if (index >= 0) {
      final contact = contacts[index];
      final hasKey =
          contact.encPublicKeyB64 != null && contact.encPublicKeyB64!.isNotEmpty;
      if (enc == null || enc.isEmpty || hasKey) return;
      await _core.contactsRepo.save(contact.copyWith(encPublicKeyB64: enc));
      await ref.read(contactsProvider.notifier).refresh();
      return;
    }

    await _core.contactsRepo.save(
      Contact(
        did: peerDid.toLowerCase(),
        name: (name != null && name.isNotEmpty) ? name : Did.shortDid(peerDid),
        encPublicKeyB64: (enc != null && enc.isNotEmpty) ? enc : null,
        addedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await ref.read(contactsProvider.notifier).refresh();
  }

  bool _applyIncomingKeyBundle(NexusChatEnvelope envelope) {
    final pub = envelope.publicData;
    if (pub == null) return false;
    final did = (pub['did'] as String?)?.toLowerCase();
    final enc = pub['enc'] as String?;
    if (did == null || enc == null) return false;
    final contacts = ref.read(contactsProvider);
    final index = contacts.indexWhere((c) => c.did.toLowerCase() == did);
    if (index < 0) return false;
    final contact = contacts[index];
    if (contact.encPublicKeyB64 == enc) return false;
    _core.contactsRepo.save(
      contact.copyWith(encPublicKeyB64: enc),
    );
    return true;
  }

  /// 处理收到的撤回通知：把目标讯息标记为已撤回。
  ///
  /// 有效性有三道关卡，缺一不可，否则任何人都能撤掉别人的讯息：
  /// 1. 签章必须正确（[EnvelopeSealer.open] 负责验签）——撤回通知的
  ///    [publicData] 没有加密，签章是唯一的信任来源。
  /// 2. 撤回者必须是讯息作者（`from` 的方向要与讯息一致）。
  /// 3. 目标讯息必须确实存在于同一个对话中。
  Future<bool> _applyIncomingRecall(NexusChatEnvelope envelope) async {
    final waku = _core.waku;
    if (waku == null) return false;
    final opened = await waku.sealer.open(envelope);
    if (opened == null) return false;

    final targetId = envelope.publicData?['target'] as String?;
    final to = envelope.publicData?['to'] as String?;
    if (targetId == null || targetId.isEmpty) return false;

    final fromMe = envelope.from.toLowerCase() == _core.did.toLowerCase();
    final peerDid = (to ?? '').startsWith('grp:')
        ? (to ?? '')
        : (fromMe ? (to ?? '') : envelope.from);
    if (peerDid.isEmpty || peerDid == '*') return false;

    final target = _findMessage(targetId);
    if (target == null) {
      // 原始讯息尚未抵达（或本机已删除）：先记下撤回，等它进来再套用。
      _pendingRecalls[targetId] = envelope.timestampMs;
      return false;
    }
    if (target.peerDid.toLowerCase() != peerDid.toLowerCase()) return false;
    // 只有作者能撤：我发的只能由我撤，对方发的只能由对方撤。
    if (target.outgoing != fromMe) return false;
    if (target.recalledAtMs != null) return false;

    await _core.messagesRepo.save(
      target.copyWith(recalledAtMs: envelope.timestampMs),
    );
    await _refreshConversationPreview(peerDid);
    return true;
  }

  /// 在本机讯息库里找出一则讯息。
  ChatMessage? _findMessage(String messageId) {
    for (final message in _core.messagesRepo.all()) {
      if (message.id == messageId) return message;
    }
    return null;
  }

  /// 重新计算某个对话的列表预览（最后一则讯息）。
  ///
  /// 删除或撤回讯息后，对话列表的摘要可能仍指向那则已不显示的讯息，
  /// 这里用剩下的最后一则重算；整串都空了就把对话一并移除。
  Future<void> _refreshConversationPreview(String peerDid) async {
    final existing = _core.conversationsRepo
        .all()
        .where((c) => c.peerDid.toLowerCase() == peerDid.toLowerCase())
        .toList();
    if (existing.isEmpty) return;
    final remaining = _core.messagesRepo.forPeer(peerDid);
    if (remaining.isEmpty) {
      await _core.conversationsRepo.remove(peerDid);
      return;
    }
    final last = remaining.last;
    // 已撤回的讯息不该在列表里泄漏原文，摘要留白。
    final hidden = last.recalledAtMs != null;
    await _core.conversationsRepo.save(
      existing.first.copyWith(
        lastText: hidden ? '' : (last.kind == MediaKind.text ? last.text : ''),
        lastMedia:
            hidden ? null : (last.kind == MediaKind.text ? null : last.kind.value),
        lastTsMs: last.timestampMs,
        lastStatus: last.outgoing ? last.status : null,
      ),
    );
  }

  Future<void> _upsertConversation(
    String peerDid,
    ChatMessage message, {
    required bool incrementUnread,
  }) async {
    final existing = _core.conversationsRepo
        .all()
        .where((c) => c.peerDid == peerDid)
        .toList();
    final contact = ref
        .read(contactsProvider)
        .where((c) => c.did.toLowerCase() == peerDid.toLowerCase())
        .toList();
    final title = contact.isNotEmpty ? contact.first.name : Did.shortDid(peerDid);

    final next = (existing.isEmpty
            ? Conversation(peerDid: peerDid, title: title)
            : existing.first)
        .copyWith(
      title: title,
      lastText: message.kind == MediaKind.text
          ? message.text
          : (message.text.isNotEmpty ? message.text : ''),
      lastMedia: message.kind == MediaKind.text ? null : message.kind.value,
      lastTsMs: message.timestampMs,
      unread: incrementUnread
          ? (existing.isEmpty ? 1 : existing.first.unread + 1)
          : (existing.isEmpty ? 0 : existing.first.unread),
      lastStatus: message.outgoing ? message.status : null,
    );
    await _core.conversationsRepo.save(next);
  }

  void _reload() {
    final conversations = _core.conversationsRepo.all();
    final groups = _core.groupsRepo.all();
    final all = _core.messagesRepo.all();
    final grouped = <String, List<ChatMessage>>{};
    for (final message in all) {
      grouped.putIfAbsent(message.peerDid, () => <ChatMessage>[]).add(message);
      _seen.add(message.id);
    }
    state = state.copyWith(
      conversations: conversations,
      groups: groups,
      messages: grouped,
    );
  }

  void _reloadGroups() {
    state = state.copyWith(groups: _core.groupsRepo.all());
  }

  // ------------------------------------------------------------ 群组

  /// 处理收到的群组邀请：解密取得群组金钥与成员清单，建立或更新本机群组。
  Future<bool> _applyIncomingGroupInvite(NexusChatEnvelope envelope) async {
    final waku = _core.waku;
    if (waku == null) return false;
    final opened = await waku.sealer.open(envelope);
    if (opened == null) return false;
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(opened.plaintext ?? '') as Map<String, dynamic>;
    } catch (_) {
      return false;
    }
    final groupId = payload['groupId'] as String?;
    final name = payload['name'] as String?;
    final keyB64 = payload['keyB64'] as String?;
    final creator = (payload['creator'] as String?)?.toLowerCase();
    final membersRaw = payload['members'];
    if (groupId == null || keyB64 == null || name == null) return false;
    final members = membersRaw is List
        ? membersRaw.map((e) => '$e'.toLowerCase()).toList()
        : <String>[];
    if (members.isEmpty) return false;

    final existing = state.groupByPeerKey('grp:$groupId');
    final group = existing == null
        ? GroupChat(
            id: groupId,
            name: name,
            memberDids: members,
            creatorDid: creator ?? '',
            keyB64: keyB64,
            createdAtMs: envelope.timestampMs,
          )
        : existing.copyWith(name: name, memberDids: members);
    await _core.groupsRepo.save(group);
    _reloadGroups();
    // 建立者不是自己时，补抓一次群组主题，确保即时收到后续讯息。
    unawaited(sync());
    return true;
  }

  /// 更新群组在列表的预览（最后一则讯息）。
  Future<void> _upsertGroupConversation(
    String peerKey,
    ChatMessage message, {
    required bool incrementUnread,
  }) async {
    final group = state.groupByPeerKey(peerKey);
    if (group == null) return;
    final hidden = message.recalledAtMs != null;
    final next = group.copyWith(
      lastText: hidden
          ? ''
          : (message.kind == MediaKind.text
              ? message.text
              : (message.text.isNotEmpty ? message.text : '')),
      lastMedia: hidden
          ? null
          : (message.kind == MediaKind.text ? null : message.kind.value),
      lastTsMs: message.timestampMs,
      unread: incrementUnread ? group.unread + 1 : group.unread,
    );
    await _core.groupsRepo.save(next);
    _reloadGroups();
  }

  /// 重新计算某个群组的列表预览（删除／撤回后）。
  Future<void> _refreshGroupPreview(String peerKey) async {
    final group = state.groupByPeerKey(peerKey);
    if (group == null) return;
    final remaining = _core.messagesRepo.forPeer(peerKey);
    if (remaining.isEmpty) {
      await _core.groupsRepo.remove(group.id);
      _reloadGroups();
      return;
    }
    final last = remaining.last;
    final hidden = last.recalledAtMs != null;
    await _core.groupsRepo.save(
      group.copyWith(
        lastText: hidden ? '' : (last.kind == MediaKind.text ? last.text : ''),
        lastMedia:
            hidden ? null : (last.kind == MediaKind.text ? null : last.kind.value),
        lastTsMs: last.timestampMs,
      ),
    );
    _reloadGroups();
  }

  /// 取得某个 DID 的加密公钥：先查联络人，没有再去金钥包频道补。
  Future<String?> _recipientKeyFor(String did) async {
    final contacts = ref.read(contactsProvider);
    final index =
        contacts.indexWhere((c) => c.did.toLowerCase() == did.toLowerCase());
    if (index >= 0) {
      final key = contacts[index].encPublicKeyB64;
      if (key != null && key.isNotEmpty) return key;
    }
    return _findKeyOnNetwork(did);
  }

  /// 建立群组：产生共享金钥，储存本机群组，并把金钥用每位成员公钥加密分发。
  ///
  /// 回传新建的群组 id；成员公钥暂时取不到时会略过该成员。
  Future<String?> createGroup({
    required String name,
    required List<String> memberDids,
  }) async {
    final waku = _core.waku;
    if (waku == null || memberDids.isEmpty) return null;
    final myDid = _core.did.toLowerCase();
    final groupId = const Uuid().v4();
    final keyB64 = base64Encode(CryptoService.newSymmetricKey());
    final members = <String>{myDid, ...memberDids.map((d) => d.toLowerCase())}
        .toList(growable: false);
    final group = GroupChat(
      id: groupId,
      name: name.trim(),
      memberDids: members,
      creatorDid: myDid,
      keyB64: keyB64,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _core.groupsRepo.save(group);
    _reloadGroups();

    final payload = <String, dynamic>{
      'groupId': groupId,
      'name': group.name,
      'members': members,
      'creator': myDid,
      'keyB64': keyB64,
    };
    for (final did in memberDids) {
      final normalized = did.toLowerCase();
      final encKey = await _recipientKeyFor(normalized);
      if (encKey == null || encKey.isEmpty) continue;
      try {
        await waku.sendGroupInvite(
          toDid: normalized,
          invite: payload,
          recipientPublicKeyB64: encKey,
        );
      } catch (_) {
        // 单一成员邀请失败不影响整体；其余成员仍会收到，稍后可重新邀请。
      }
    }
    return groupId;
  }

  /// 邀请新成员加入既有群组（用既有金钥重新分发邀请）。
  Future<bool> addGroupMember(String groupId, String did) async {
    final waku = _core.waku;
    final group = _core.groupsRepo.byId(groupId);
    if (waku == null || group == null) return false;
    final normalized = did.toLowerCase();
    if (group.memberDids.contains(normalized)) return false;
    final encKey = await _recipientKeyFor(normalized);
    if (encKey == null || encKey.isEmpty) return false;
    final members = <String>[...group.memberDids, normalized];
    await _core.groupsRepo.save(group.copyWith(memberDids: members));
    _reloadGroups();
    final payload = <String, dynamic>{
      'groupId': groupId,
      'name': group.name,
      'members': members,
      'creator': group.creatorDid,
      'keyB64': group.keyB64,
    };
    try {
      await waku.sendGroupInvite(
        toDid: normalized,
        invite: payload,
        recipientPublicKeyB64: encKey,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 退出群组：移除本机群组与其讯息（去中心化网路无法通知他人）。
  Future<void> leaveGroup(String groupId) async {
    final peerKey = 'grp:$groupId';
    await _core.messagesRepo.removeByPeer(peerKey);
    await _core.groupsRepo.remove(groupId);
    _reloadGroups();
  }

  /// 删除群组（只删本机，语意等同 [leaveGroup]）。
  Future<void> deleteGroup(String groupId) async => leaveGroup(groupId);

  /// 传送群组讯息（乐观更新）。
  Future<void> sendGroupContent(String groupId, MessageContent content) async {
    if (content.kind == MediaKind.text && content.text.trim().isEmpty) return;
    final waku = _core.waku;
    final group = _core.groupsRepo.byId(groupId);
    if (waku == null || group == null) return;

    final peerKey = 'grp:$groupId';
    final mediaB64 = content.mediaBytes == null
        ? null
        : base64Encode(content.mediaBytes!);

    if (content.mediaBytes != null &&
        content.mediaBytes!.length > kMaxMediaBytes) {
      final failed = ChatMessage(
        id: 'tmp-${const Uuid().v4()}',
        peerDid: peerKey,
        text: content.text,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        outgoing: true,
        status: MessageStatus.failed,
        error: 'media-too-large',
        kind: content.kind,
        mediaB64: mediaB64,
        mediaMime: content.mediaMime,
        mediaDurationMs: content.mediaDurationMs,
        mediaName: content.mediaName,
      );
      await _core.messagesRepo.save(failed);
      await _upsertGroupConversation(peerKey, failed, incrementUnread: false);
      _reload();
      return;
    }

    final tempId = 'tmp-${const Uuid().v4()}';
    final pending = ChatMessage(
      id: tempId,
      peerDid: peerKey,
      text: content.text,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      outgoing: true,
      status: MessageStatus.sending,
      kind: content.kind,
      mediaB64: mediaB64,
      mediaMime: content.mediaMime,
      mediaDurationMs: content.mediaDurationMs,
      mediaName: content.mediaName,
      senderDid: _core.did,
    );
    _insertLocal(pending);

    try {
      final envelope = await waku.sendGroupContent(
        groupId: groupId,
        key: base64Decode(group.keyB64),
        content: content,
        senderName: _core.settings.nickname,
      );
      _seen.add(envelope.id);
      await _core.messagesRepo.remove(tempId);
      final sent = pending.copyWith(
        id: envelope.id,
        status: MessageStatus.sent,
        timestampMs: envelope.timestampMs,
      );
      await _core.messagesRepo.save(sent);
      await _upsertGroupConversation(peerKey, sent, incrementUnread: false);
      _reload();
    } catch (error) {
      await _finalizeMessage(
        tempId,
        pending.copyWith(status: MessageStatus.failed, error: '$error'),
      );
    }
  }

  /// 送出讯息（乐观更新）。[content] 可以是文字、图片或语音。
  Future<void> sendContent(String peerDid, MessageContent content) async {
    if (content.kind == MediaKind.text && content.text.trim().isEmpty) return;
    final waku = _core.waku;
    if (waku == null) return;

    final mediaB64 = content.mediaBytes == null
        ? null
        : base64Encode(content.mediaBytes!);

    // 媒体过大：直接标记失败，避免塞爆 Waku 节点。
    if (content.mediaBytes != null &&
        content.mediaBytes!.length > kMaxMediaBytes) {
      final failed = ChatMessage(
        id: 'tmp-${const Uuid().v4()}',
        peerDid: peerDid,
        text: content.text,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        outgoing: true,
        status: MessageStatus.failed,
        error: 'media-too-large',
        kind: content.kind,
        mediaB64: mediaB64,
        mediaMime: content.mediaMime,
        mediaDurationMs: content.mediaDurationMs,
        mediaName: content.mediaName,
      );
      await _core.messagesRepo.save(failed);
      await _upsertConversation(peerDid, failed, incrementUnread: false);
      _reload();
      return;
    }

    final contacts = ref.read(contactsProvider);
    var contact = contacts
        .where((c) => c.did.toLowerCase() == peerDid.toLowerCase())
        .toList();
    var encKey = contact.isNotEmpty ? contact.first.encPublicKeyB64 : null;
    encKey ??= await _findKeyOnNetwork(peerDid);

    final tempId = 'tmp-${const Uuid().v4()}';
    final pending = ChatMessage(
      id: tempId,
      peerDid: peerDid,
      text: content.text,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      outgoing: true,
      status: MessageStatus.sending,
      kind: content.kind,
      mediaB64: mediaB64,
      mediaMime: content.mediaMime,
      mediaDurationMs: content.mediaDurationMs,
      mediaName: content.mediaName,
    );
    _insertLocal(pending);

    if (encKey == null || encKey.isEmpty) {
      await _finalizeMessage(
        tempId,
        pending.copyWith(status: MessageStatus.failed, error: 'no-key'),
      );
      return;
    }

    try {
      final envelope = await waku.sendContent(
        toDid: peerDid,
        recipientPublicKeyB64: encKey,
        content: content,
        senderName: _core.settings.nickname,
      );
      _seen.add(envelope.id);
      await _core.messagesRepo.remove(tempId);
      final sent = pending.copyWith(
        id: envelope.id,
        status: MessageStatus.sent,
        timestampMs: envelope.timestampMs,
      );
      await _core.messagesRepo.save(sent);
      await _upsertConversation(peerDid, sent, incrementUnread: false);
      _reload();
    } catch (error) {
      await _finalizeMessage(
        tempId,
        pending.copyWith(status: MessageStatus.failed, error: '$error'),
      );
    }
  }

  Future<void> _finalizeMessage(String oldId, ChatMessage next) async {
    await _core.messagesRepo.remove(oldId);
    await _core.messagesRepo.save(next);
    _reload();
  }

  void _insertLocal(ChatMessage message) {
    final list = List<ChatMessage>.from(state.forPeer(message.peerDid))
      ..add(message)
      ..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
    final grouped = Map<String, List<ChatMessage>>.from(state.messages);
    grouped[message.peerDid] = list;
    state = state.copyWith(messages: grouped);
  }

  /// 重试失败的讯息。
  Future<void> retry(String messageId) async {
    final message = state.messages.values
        .expand((e) => e)
        .where((m) => m.id == messageId)
        .toList();
    if (message.isEmpty) return;
    await _core.messagesRepo.remove(messageId);
    _seen.remove(messageId);
    _reload();
    final target = message.first;
    await sendContent(target.peerDid, MessageContent.fromChatMessage(target));
  }

  /// 在金钥包频道寻找某个 DID 的公钥。
  Future<String?> _findKeyOnNetwork(String peerDid) async {
    final waku = _core.waku;
    if (waku == null) return null;
    try {
      final messages = await waku.fetch(<String>[ContentTopics.keyBundle]);
      for (final message in messages) {
        final envelope = NexusChatEnvelope.decodeBase64(message.payloadBase64);
        if (envelope == null || envelope.type != EnvelopeType.keyBundle) continue;
        final pub = envelope.publicData;
        if (pub == null) continue;
        if ((pub['did'] as String?)?.toLowerCase() != peerDid.toLowerCase()) {
          continue;
        }
        final enc = pub['enc'] as String?;
        if (enc == null) continue;
        final contacts = ref.read(contactsProvider);
        final index =
            contacts.indexWhere((c) => c.did.toLowerCase() == peerDid.toLowerCase());
        if (index >= 0) {
          final updated = contacts[index].copyWith(encPublicKeyB64: enc);
          await _core.contactsRepo.save(updated);
          await ref.read(contactsProvider.notifier).refresh();
        }
        return enc;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<void> markRead(String peerDid) async {
    if (peerDid.startsWith('grp:')) {
      final group = state.groupByPeerKey(peerDid);
      if (group == null || group.unread == 0) return;
      await _core.groupsRepo.save(group.copyWith(unread: 0));
      _reloadGroups();
      return;
    }
    final list = _core.conversationsRepo
        .all()
        .where((c) => c.peerDid == peerDid)
        .toList();
    if (list.isEmpty || list.first.unread == 0) return;
    await _core.conversationsRepo.save(list.first.copyWith(unread: 0));
    _reload();
  }

  Future<void> togglePin(String peerDid) async {
    if (peerDid.startsWith('grp:')) {
      final group = state.groupByPeerKey(peerDid);
      if (group == null) return;
      await _core.groupsRepo.save(group.copyWith(pinned: !group.pinned));
      _reloadGroups();
      return;
    }
    final list = _core.conversationsRepo
        .all()
        .where((c) => c.peerDid == peerDid)
        .toList();
    if (list.isEmpty) return;
    await _core.conversationsRepo
        .save(list.first.copyWith(pinned: !list.first.pinned));
    _reload();
  }

  Future<void> deleteConversation(String peerDid) async {
    await _core.messagesRepo.removeByPeer(peerDid);
    if (peerDid.startsWith('grp:')) {
      await _core.groupsRepo.remove(peerDid.substring(4));
      _reloadGroups();
      return;
    }
    await _core.conversationsRepo.remove(peerDid);
    _reload();
  }

  /// 删除单则讯息（**只删本机**，不通知对方）。
  ///
  /// 去中心化网路没有「把对方那一份也删掉」的机制，所以这里只移除本机
  /// 纪录；对方仍看得到原讯息。要让双方都看不到请用 [recallMessage]。
  /// 回传该讯息所属的 peerDid 供 UI 更新，找不到则回传 null。
  Future<String?> deleteMessage(String messageId) async {
    final target = _findMessage(messageId);
    if (target == null) return null;
    await _core.messagesRepo.remove(messageId);
    // 同时留墓碑与 _seen：前者挡重开后的全量回溯，后者挡本轮重复套用。
    await _core.messagesRepo.markDeleted(messageId);
    _seen.add(messageId);
    await _refreshConversationPreview(target.peerDid);
    _reload();
    return target.peerDid;
  }

  /// 撤回自己发出的讯息：广播撤回通知，双方都改显示「讯息已撤回」。
  ///
  /// 限制：只能撤自己发出、已送出（非失败）且尚未撤回的讯息。
  /// 去中心化网路下原始内容仍留在双方储存里，撤回只是让介面不再显示，
  /// 这一点与「删除」的差别必须让使用者知道（见确认对话框文案）。
  Future<bool> recallMessage(String messageId) async {
    final waku = _core.waku;
    final target = _findMessage(messageId);
    if (waku == null || target == null) return false;
    if (!target.outgoing) return false;
    if (target.status == MessageStatus.failed) return false;
    if (target.recalledAtMs != null) return false;

    final isGroup = target.peerDid.startsWith('grp:');
    try {
      if (isGroup) {
        await waku.sendGroupRecall(
          groupId: target.peerDid.substring(4),
          targetMessageId: messageId,
        );
      } else {
        final envelope = await waku.sendRecall(
          toDid: target.peerDid,
          targetMessageId: messageId,
        );
        _seen.add(envelope.id);
      }
    } catch (error, stackTrace) {
      debugPrint('recall failed: $error\n$stackTrace');
      return false;
    }
    await _core.messagesRepo.save(
      target.copyWith(recalledAtMs: DateTime.now().millisecondsSinceEpoch),
    );
    if (isGroup) {
      await _refreshGroupPreview(target.peerDid);
    } else {
      await _refreshConversationPreview(target.peerDid);
    }
    _reload();
    return true;
  }

  /// 广播自己的金钥包。
  ///
  /// 离线或节点不可用时只记录、不抛错：金钥包会在之后的同步轮询中自动补发，
  /// 绝不能因此挡住进入主介面或发送讯息。
  Future<void> publishKeys() async {
    final waku = _core.waku;
    if (waku == null) return;
    try {
      await waku.publishKeyBundle(
        nickname: ref.read(settingsProvider).nickname,
      );
    } catch (error, stackTrace) {
      debugPrint('publishKeys failed: $error\n$stackTrace');
    }
  }
}

// ==========================================================================
// 钱包资讯（多链）
// ==========================================================================

/// 钱包页面的帐户资讯（余额 / chain id / 域名）。
///
/// 依 [AppSettings.chain] 选择对应的链服务：以太坊走 JSON-RPC，
/// TRON 走 TronGrid HTTP API。两者都回传统一的 [ChainAccountInfo]。
final walletInfoProvider = FutureProvider.autoDispose<ChainAccountInfo>((
  ref,
) async {
  final settings = ref.watch(settingsProvider);
  final identity = ref.watch(sessionProvider).identity;
  if (identity == null) {
    return ChainAccountInfo(
      chain: settings.chain,
      address: '',
      error: 'no-identity',
    );
  }

  final chain = settings.chain;
  final endpoint = settings.rpcFor(chain);

  if (chain == ChainType.tron) {
    final service = TronService(apiUrl: endpoint);
    try {
      return await service.summary(identity.tronAddress);
    } finally {
      service.dispose();
    }
  }

  // 其余链（以太坊 / Base / Arbitrum / BSC / Besu）都是 EVM：同一个 0x
  // 地址、同一套 JSON-RPC，差别只在 ENS —— 以太坊主网以外不查。
  final service = EthereumService(
    rpcUrl: endpoint,
    chain: chain,
    enableEns: ChainConfig.of(chain).supportsEns,
  );
  try {
    return await service.summary(identity.address);
  } finally {
    service.dispose();
  }
});

// ==========================================================================
// 转帐
// ==========================================================================

/// 转帐状态。
class SendState {
  const SendState({this.busy = false, this.error, this.result});

  final bool busy;

  /// 失败代码（`insufficient-funds` / `network` / …），供 UI 映射文案。
  final String? error;

  /// 成功后的交易结果。
  final TxResult? result;

  SendState copyWith({
    bool? busy,
    String? error,
    TxResult? result,
    bool clearError = false,
    bool clearResult = false,
  }) {
    return SendState(
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
      result: clearResult ? null : (result ?? this.result),
    );
  }
}

final walletSendProvider =
    NotifierProvider<WalletSendController, SendState>(WalletSendController.new);

/// 执行原生代币转帐：依当前链分派到 EVM / TRON。
class WalletSendController extends Notifier<SendState> {
  @override
  SendState build() => const SendState();

  /// 送出转帐。成功时回传交易结果，失败回传 null 并把错误写进 state。
  Future<TxResult?> send({
    required String toAddress,
    required double amount,
  }) async {
    final settings = ref.read(settingsProvider);
    final identity = ref.read(sessionProvider).identity;
    if (identity == null) {
      state = state.copyWith(error: 'no-identity', clearResult: true);
      return null;
    }

    state = state.copyWith(
      busy: true,
      clearError: true,
      clearResult: true,
    );
    try {
      final result = await TxService.send(
        chain: settings.chain,
        rpcUrl: settings.rpcFor(settings.chain),
        privateKeyHex: identity.ethPrivateHex,
        toAddress: toAddress,
        amount: amount,
        explorerBase: ChainConfig.of(settings.chain).explorerUrl,
      );
      state = state.copyWith(busy: false, result: result);
      // 余额已变动，让钱包页重新拉取。
      ref.invalidate(walletInfoProvider);
      return result;
    } on TxException catch (error) {
      state = state.copyWith(busy: false, error: error.code);
      return null;
    } catch (_) {
      state = state.copyWith(busy: false, error: 'network');
      return null;
    }
  }

  /// 送出代币转帐（ERC-20 / TRC-20，依目前链自动分派）。
  ///
  /// 成功时回传交易结果，失败回传 null 并把错误码写入 state。
  Future<TxResult?> sendToken({
    required TokenDef token,
    required String toAddress,
    required double amount,
  }) async {
    final settings = ref.read(settingsProvider);
    final identity = ref.read(sessionProvider).identity;
    if (identity == null) {
      state = state.copyWith(error: 'no-identity', clearResult: true);
      return null;
    }

    state = state.copyWith(
      busy: true,
      clearError: true,
      clearResult: true,
    );
    try {
      final result = await TxService.sendToken(
        chain: settings.chain,
        rpcUrl: settings.rpcFor(settings.chain),
        privateKeyHex: identity.ethPrivateHex,
        contractAddress: token.address,
        toAddress: toAddress,
        amount: amount,
        decimals: token.decimals,
        explorerBase: ChainConfig.of(settings.chain).explorerUrl,
      );
      state = state.copyWith(busy: false, result: result);
      // 余额已变动，让钱包页重新拉取。
      ref.invalidate(walletInfoProvider);
      // 记一笔本机发送历史（ERC-20 / TRC-20 通用）。
      ref.read(tokenTxHistoryProvider.notifier).add(TokenTxRecord(
            chainId: settings.chain.id,
            symbol: token.symbol,
            contract: token.address,
            toAddress: toAddress,
            amount: amount,
            hash: result.hash,
            timestamp: DateTime.now().millisecondsSinceEpoch,
            standard: settings.chain == ChainType.tron ? 'trc20' : 'erc20',
            explorerUrl: result.explorerUrl,
          ));
      return result;
    } on TxException catch (error) {
      state = state.copyWith(busy: false, error: error.code);
      return null;
    } catch (_) {
      state = state.copyWith(busy: false, error: 'network');
      return null;
    }
  }

  void reset() => state = const SendState();
}


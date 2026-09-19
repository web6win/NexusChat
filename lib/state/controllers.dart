import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueNotifier, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../app/core.dart';
import '../data/crypto/app_identity.dart';
import '../data/crypto/did.dart';
import '../data/ethereum/ethereum_service.dart';
import '../data/ethereum/tron_service.dart';
import '../data/ethereum/tx_service.dart';
import '../data/ethereum/chain_account.dart';
import '../data/models/app_settings.dart';
import '../data/models/chain.dart';
import '../data/models/chat_models.dart';
import '../data/models/security_settings.dart';
import '../data/security/vault.dart';
import '../data/waku/content_topics.dart';
import '../data/waku/envelope.dart';
import '../data/waku/message_content.dart';
import '../data/waku/node_probe.dart';
import '../data/waku/waku_message.dart';
import '../data/waku/waku_service.dart';
import '../data/waku/waku_transport.dart';
import '../core/l10n/app_locale.dart';

/// 身份發生變化時遞增，讓路由重新判斷導向。
final ValueNotifier<int> sessionVersion = ValueNotifier<int>(0);

/// 核心容器（在 main 中以 override 注入）。
final coreProvider = Provider<Core>((ref) {
  throw UnimplementedError('coreProvider 必須在 main() 中以 overrideWithValue 注入');
});

// ==========================================================================
// 設定
// ==========================================================================

/// 全站設定控制器。
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

  /// 覆寫整份節點清單（內建節點會被強制保留在最前面）。
  ///
  /// 若目前使用中的節點剛好被移除，會自動退回清單中的第一台，避免連線
  /// 指向已不存在的節點。
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

  /// 新增自訂節點。回傳錯誤碼（null 代表成功）。
  Future<String?> addNode(String raw) async {
    final url = AppSettings.normalizeNodeUrl(raw);
    if (url.isEmpty) return 'invalid';
    if (state.nodeUrls.contains(url)) return 'duplicate';
    await setNodeUrls(<String>[...state.nodeUrls, url]);
    return null;
  }

  /// 移除自訂節點（內建節點不可移除）。
  Future<void> removeNode(String url) async {
    if (AppSettings.isBuiltinNode(url)) return;
    await setNodeUrls(
      state.nodeUrls.where((u) => u != url).toList(growable: false),
    );
  }

  /// 還原成預設節點（僅保留內建節點）。
  Future<void> resetNodes() => setNodeUrls(const <String>[]);

  /// 切換目前使用中的節點。
  ///
  /// 這是唯一會被連線的節點，因此切換後會立刻重建連線並重新同步。
  Future<void> setActiveNode(String url) async {
    if (!state.nodeUrls.contains(url) || state.activeNodeUrl == url) return;
    await _persist(state.copyWith(activeNodeUrl: url));
    await _reconnect();
  }

  /// 節點清單或使用中節點變更後，重建連線並重新同步。
  Future<void> _reconnect() async {
    await _core.applyTransport(state.resolvedActiveNodeUrl);
    ref.invalidate(networkStatusProvider);
    ref.invalidate(nodeStatusProvider);
    ref.read(chatControllerProvider.notifier).resetSync();
    await ref.read(chatControllerProvider.notifier).sync();
  }

  Future<void> setRpcUrl(String url) => _persist(state.copyWith(rpcUrl: url));

  /// 切換錢包顯示的區塊鏈（僅影響錢包頁，不影響聊天身份 did:ethr）。
  Future<void> setChain(ChainType chain) =>
      _persist(state.copyWith(chain: chain));

  Future<void> setTronRpcUrl(String url) =>
      _persist(state.copyWith(tronRpcUrl: url));

  /// Besu 聯盟鏈（WEB6）的 JSON-RPC 端點。
  Future<void> setBesuRpcUrl(String url) =>
      _persist(state.copyWith(besuRpcUrl: url));

  /// 依鏈設定對應的 RPC 端點。
  Future<void> setRpcFor(ChainType chain, String url) => switch (chain) {
        ChainType.ethereum => setRpcUrl(url),
        ChainType.tron => setTronRpcUrl(url),
        ChainType.besu => setBesuRpcUrl(url),
      };

  Future<void> setNickname(String nickname) =>
      _persist(state.copyWith(nickname: nickname));

  Future<void> setOnboarded(bool value) =>
      _persist(state.copyWith(onboarded: value));
}

/// 目前語系（空字串代表跟隨系統）。
final localeProvider = Provider<AppLocale?>((ref) {
  final code = ref.watch(settingsProvider).localeCode;
  if (code.isEmpty) return null;
  return AppLocale.fromCode(code);
});

// ==========================================================================
// 身份
// ==========================================================================

/// 身份狀態。
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

  /// 本機已有身份，但尚未輸入密碼解鎖（記憶體中沒有任何秘密）。
  final bool locked;

  /// 存在舊版明文身份，需要設定密碼完成遷移。
  final bool needsMigration;

  /// 已解鎖。
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

/// 身份控制器：建立、匯入、解鎖、鎖定、刪除。
///
/// 同時負責**閒置自動鎖定**：任何使用者互動都會重置計時器，
/// 逾時後呼叫 [lock] 把秘密清出記憶體。
final sessionProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

class SessionController extends Notifier<SessionState> {
  Timer? _idleTimer;
  DateTime? _lastActivity;

  /// 互動節流視窗：避免每次滑鼠移動都重建計時器。
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

  // ------------------------------------------------------------ 建立 / 匯入

  /// 建立身份並立即以 [password] 加密保存。
  ///
  /// 回傳錯誤代碼（`create-failed`）或 `null` 表示成功。
  Future<String?> createIdentity({required String password}) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final identity = await _core.createIdentity(password: password);
      await _afterIdentity(identity, nickname: '');
      return null;
    } catch (_) {
      state = state.copyWith(busy: false, error: 'create-failed');
      return 'create-failed';
    }
  }

  /// 由助記詞還原身份；錯誤代碼 `invalid-mnemonic` / `restore-failed`。
  Future<String?> restoreIdentity(
    String mnemonic, {
    required String password,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final identity =
          await _core.restoreIdentity(mnemonic, password: password);
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

  /// 由私鑰匯入身份；失敗時回傳 null 並把錯誤代碼寫進 state。
  ///
  /// 錯誤代碼：`invalid-private-key`（格式 / 範圍不合法）、`import-failed`。
  Future<String?> importPrivateKey(
    String privateHex, {
    required String password,
  }) async {
    // 先做本地格式檢查，讓 UI 能給出精確的錯誤提示。
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

  /// 把舊版明文身份遷移進加密保險庫；錯誤代碼 `migrate-failed`。
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

  // ------------------------------------------------------------ 解鎖 / 鎖定

  /// 以密碼解鎖。回傳錯誤代碼或 `null`。
  ///
  /// 錯誤代碼：`bad-password`（密碼錯或密文毀損）、`unlock-failed`。
  Future<String?> unlock(String password) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final identity = await _core.unlock(password);
      await _afterIdentity(
        identity,
        nickname: ref.read(settingsProvider).nickname,
      );
      // 通知路由重新評估：解鎖後才允許離開鎖屏。
      sessionVersion.value++;
      _restartIdleTimer();
      return null;
    } on VaultException catch (error) {
      state = state.copyWith(busy: false, error: error.code);
      return error.code;
    } catch (_) {
      state = state.copyWith(busy: false, error: 'unlock-failed');
      return 'unlock-failed';
    }
  }

  /// 立即鎖定：清空秘密、斷開連線、回到鎖屏。
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

  /// 記錄一次使用者互動，用來延後自動鎖定。
  ///
  /// 以 10 秒節流，避免高頻事件（滑鼠移動）造成多餘的計時器重建。
  void noteActivity() {
    if (!state.hasIdentity) return;
    final now = DateTime.now();
    final last = _lastActivity;
    if (last != null && now.difference(last) < _activityThrottle) return;
    _lastActivity = now;
    _restartIdleTimer();
  }

  /// 頁面切到背景時呼叫（僅在開啟 lockOnHide 時生效）。
  Future<void> onAppHidden() async {
    if (!_core.security.lockOnHide) return;
    if (!state.hasIdentity) return;
    await lock();
  }

  Future<void> _stopChat() async {
    try {
      await ref.read(chatControllerProvider.notifier).stop();
    } catch (_) {
      // 尚未建立連線時不需處理。
    }
  }

  void _restartIdleTimer() {
    _cancelIdleTimer();
    final duration = _core.security.autoLockDuration;
    if (duration == null) return;
    _idleTimer = Timer(duration, () {
      // 只有仍處於解鎖狀態才需要鎖定。
      if (state.hasIdentity) lock();
    });
  }

  void _cancelIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  Future<void> _afterIdentity(AppIdentity identity, {String? nickname}) async {
    await _core.applyTransport(
      ref.read(settingsProvider).resolvedActiveNodeUrl,
    );
    if (nickname != null && nickname.isNotEmpty) {
      await _core.publishKeyBundleIfReady(nickname);
    }
    state = SessionState(identity: identity);
    ref.invalidate(contactsProvider);
    ref.invalidate(networkStatusProvider);
    await ref.read(chatControllerProvider.notifier).sync();
  }

  /// 擦除本機所有資料（身份、訊息、聯絡人）。
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
// 安全設定
// ==========================================================================

/// 安全設定控制器（自動鎖定時長等）。
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
    // 讓閒置計時器立即套用新設定。
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
// 聯絡人
// ==========================================================================

/// 聯絡人控制器。
final contactsProvider =
    NotifierProvider<ContactsController, List<Contact>>(ContactsController.new);

class ContactsController extends Notifier<List<Contact>> {
  @override
  List<Contact> build() => ref.read(coreProvider).contactsRepo.all();

  Core get _core => ref.read(coreProvider);

  /// 由 DID / 地址 / ENS 加入聯絡人。回傳錯誤碼字串（null 代表成功）。
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
      final service = EthereumService(rpcUrl: ref.read(settingsProvider).rpcUrl);
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

  /// 從 Waku 的金鑰包頻道補齊聯絡人的加密公鑰。
  ///
  /// 回傳 `true` 表示有成功寫入（或更新）至少一個聯絡人的公鑰；
  /// `false` 表示沒有變化或發生錯誤。回傳值主要給 UI 做 snackbar 回饋。
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
      // 金鑰包是非必要資料，不能讓同步錯誤炸掉整個頁面；
      // 但開發/測試階段要把錯誤印出來，否則「同步中」會永遠查不到原因。
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
// 網路狀態
// ==========================================================================

/// 傳輸層健康狀態。
final networkStatusProvider =
    FutureProvider<TransportHealth>((ref) async {
  final core = ref.watch(coreProvider);
  final waku = core.waku;
  if (waku == null) return const TransportHealth(ok: false, detail: 'no-identity');
  return waku.health();
});

/// 探測節點清單中的每一台（設定頁顯示節點狀態）。
///
/// 實際連線只有使用中的那一台，但這裡一律探測**整份節點清單**，使用者才能
/// 在切換前就看到哪一台可用。探測只發 `/health`，不會影響目前連線；
/// 用完即釋放暫時建立的 HTTP 連線。
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

/// 聊天畫面狀態。
class ChatState {
  const ChatState({
    this.conversations = const <Conversation>[],
    this.messages = const <String, List<ChatMessage>>{},
    this.loading = false,
  });

  final List<Conversation> conversations;
  final Map<String, List<ChatMessage>> messages;
  final bool loading;

  ChatState copyWith({
    List<Conversation>? conversations,
    Map<String, List<ChatMessage>>? messages,
    bool? loading,
  }) {
    return ChatState(
      conversations: conversations ?? this.conversations,
      messages: messages ?? this.messages,
      loading: loading ?? this.loading,
    );
  }

  List<ChatMessage> forPeer(String peerDid) =>
      messages[peerDid] ?? const <ChatMessage>[];
}

/// 聊天控制器：負責同步 Waku、收發訊息與維護對話列表。
final chatControllerProvider =
    NotifierProvider<ChatController, ChatState>(ChatController.new);

class ChatController extends Notifier<ChatState> {
  Timer? _timer;
  final Set<String> _seen = <String>{};
  bool _syncing = false;
  DateTime? _lastKeyPublish;

  /// 上次把同步錯誤寫進 console 的時間；用來節流，避免每 1.2 秒洗版。
  DateTime? _lastSyncErrorLog;

  /// 輪詢間隔。訊息實際上是靠節點的 filter 推播，這裡只是去取快取，
  /// 所以可以拉得很密；較重的 store / relay 查詢由傳輸層自行節流。
  static const _pollInterval = Duration(milliseconds: 1200);
  static const _keyRepublishInterval = Duration(minutes: 2);

  /// 單則媒體的最大體積（位元組）。超過就直接標記失敗，避免塞爆 Waku 節點
  /// 的單則大小上限（預設約 1MB，且媒體訊息不帶「給自己的副本」）。
  static const int _maxMediaBytes = 700 * 1024;

  @override
  ChatState build() {
    final core = ref.read(coreProvider);
    final conversations = core.conversationsRepo.all();
    final all = core.messagesRepo.all();
    final grouped = <String, List<ChatMessage>>{};
    for (final message in all) {
      grouped.putIfAbsent(message.peerDid, () => <ChatMessage>[]).add(message);
    }
    for (final key in grouped.keys) {
      _seen.addAll(grouped[key]!.map((m) => m.id));
    }
    return ChatState(conversations: conversations, messages: grouped);
  }

  Core get _core => ref.read(coreProvider);

  /// 啟動輪詢（由殼層呼叫）。
  ///
  /// 第一輪一定是全量回溯（[full] = true）：增量同步只會看上次同步之後的
  /// 訊息，若之前因為「對方不在聯絡人清單」等原因漏接，重開才補得回來。
  Future<void> start() async {
    await sync(full: true);
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) => sync());
  }

  /// 手動重新拉取：清掉同步時間戳記後跑一次全量回溯。
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

  /// 拉取新訊息並解密。
  Future<void> sync({bool full = false}) async {
    final waku = _core.waku;
    if (waku == null || _syncing) return;
    _syncing = true;
    try {
      // 定期重發金鑰包：剛加的聯絡人、或錯過首次廣播的客戶端，都能靠
      // store 補到公鑰。
      await _maybeRepublishKeys(waku);
      final contacts = ref.read(contactsProvider);
      // 輪詢對象 = 聯絡人 + 已經有對話的對象；收件匣與金鑰包頻道由
      // topicsFor 自動帶入，所以「對方加了我、我還沒加對方」也收得到。
      final peers = <String>{
        ...contacts.map((c) => c.did),
        ...state.conversations.map((c) => c.peerDid),
        ...state.messages.keys,
      };
      final topics = waku.topicsFor(peers);
      // 先確保節點已把這些頻道推播給我們：之後每輪只是去取節點收好的快取，
      // 不需要等下一輪才有機會命中，達到即時接收。
      await waku.subscribe(topics);
      final since = _core.settings.lastSyncMs;
      final messages = await waku.fetch(
        topics,
        // full = true 時不帶時間過濾，讓傳輸層用預設的 48 小時視窗回溯
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
      // 網路錯誤保留既有畫面，等下一次輪詢；但要把原因印出來（節流），
      // 否則「聯絡人一直同步中」這種問題會完全查不到線索。
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
      // 節點暫時不可用（例如還沒連上任何 peer），等下一輪再試
    }
  }

  Future<bool> _handleMessage(WakuMessage message) async {
    final waku = _core.waku;
    if (waku == null) return false;
    final envelope = NexusChatEnvelope.decodeBase64(message.payloadBase64);
    if (envelope == null) return false;
    if (_seen.contains(envelope.id)) return false;

    if (envelope.type == EnvelopeType.keyBundle) {
      _seen.add(envelope.id);
      final ok = _applyIncomingKeyBundle(envelope);
      if (ok) {
        await ref.read(contactsProvider.notifier).refresh();
        return true;
      }
      return false;
    }
    if (envelope.type != EnvelopeType.chat) return false;

    final myDid = _core.did;
    final outgoing = envelope.from.toLowerCase() == myDid.toLowerCase();
    final peerDid = outgoing ? envelope.to : envelope.from;
    if (peerDid.isEmpty || peerDid == '*') return false;

    final opened = await waku.sealer.open(envelope);
    if (opened == null) return false;
    final content = MessageContent.decode(opened.plaintext ?? '');
    if (content.kind == MediaKind.text && content.text.isEmpty) return false;
    _seen.add(envelope.id);

    // 第一次收到某人訊息時自動建立名片：對方不需要事先加你為聯絡人，
    // 你這邊也不會因為沒加他而看不到人。
    if (!outgoing) await _ensureContact(peerDid, envelope);

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
    );
    await _core.messagesRepo.save(chatMessage);
    await _upsertConversation(peerDid, chatMessage, incrementUnread: !outgoing);
    return true;
  }

  /// 確保某個 DID 在通訊錄裡；若封包帶有對方的加密公鑰則一併寫入，
  /// 這樣馬上就能回覆，不必等下一次金鑰包廣播。
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
    final all = _core.messagesRepo.all();
    final grouped = <String, List<ChatMessage>>{};
    for (final message in all) {
      grouped.putIfAbsent(message.peerDid, () => <ChatMessage>[]).add(message);
      _seen.add(message.id);
    }
    state = state.copyWith(conversations: conversations, messages: grouped);
  }

  /// 送出訊息（樂觀更新）。[content] 可以是文字、圖片或語音。
  Future<void> sendContent(String peerDid, MessageContent content) async {
    if (content.kind == MediaKind.text && content.text.trim().isEmpty) return;
    final waku = _core.waku;
    if (waku == null) return;

    final mediaB64 = content.mediaBytes == null
        ? null
        : base64Encode(content.mediaBytes!);

    // 媒體過大：直接標記失敗，避免塞爆 Waku 節點。
    if (content.mediaBytes != null &&
        content.mediaBytes!.length > _maxMediaBytes) {
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

  /// 重試失敗的訊息。
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

  /// 在金鑰包頻道尋找某個 DID 的公鑰。
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
    final list = _core.conversationsRepo
        .all()
        .where((c) => c.peerDid == peerDid)
        .toList();
    if (list.isEmpty || list.first.unread == 0) return;
    await _core.conversationsRepo.save(list.first.copyWith(unread: 0));
    _reload();
  }

  Future<void> togglePin(String peerDid) async {
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
    await _core.conversationsRepo.remove(peerDid);
    _reload();
  }

  /// 廣播自己的金鑰包。
  Future<void> publishKeys() async {
    final waku = _core.waku;
    if (waku == null) return;
    await waku.publishKeyBundle(
      nickname: ref.read(settingsProvider).nickname,
    );
  }
}

// ==========================================================================
// 錢包資訊（多鏈）
// ==========================================================================

/// 錢包頁面的帳戶資訊（餘額 / chain id / 域名）。
///
/// 依 [AppSettings.chain] 選擇對應的鏈服務：以太坊走 JSON-RPC，
/// TRON 走 TronGrid HTTP API。兩者都回傳統一的 [ChainAccountInfo]。
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

  switch (settings.chain) {
    case ChainType.ethereum:
      final service = EthereumService(rpcUrl: settings.rpcUrl);
      try {
        return await service.summary(identity.address);
      } finally {
        service.dispose();
      }
    case ChainType.tron:
      final service = TronService(apiUrl: settings.tronRpcUrl);
      try {
        return await service.summary(identity.tronAddress);
      } finally {
        service.dispose();
      }
    case ChainType.besu:
      // Besu 聯盟鏈 EVM 相容，沿用 JSON-RPC 查詢；關閉 ENS 以免多打無用的 RPC。
      final service = EthereumService(
        rpcUrl: settings.besuRpcUrl,
        chain: ChainType.besu,
        enableEns: false,
      );
      try {
        return await service.summary(identity.address);
      } finally {
        service.dispose();
      }
  }
});

// ==========================================================================
// 轉帳
// ==========================================================================

/// 轉帳狀態。
class SendState {
  const SendState({this.busy = false, this.error, this.result});

  final bool busy;

  /// 失敗代碼（`insufficient-funds` / `network` / …），供 UI 映射文案。
  final String? error;

  /// 成功後的交易結果。
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

/// 執行原生代幣轉帳：依當前鏈分派到 EVM / TRON。
class WalletSendController extends Notifier<SendState> {
  @override
  SendState build() => const SendState();

  /// 送出轉帳。成功時回傳交易結果，失敗回傳 null 並把錯誤寫進 state。
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
      // 餘額已變動，讓錢包頁重新拉取。
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

  void reset() => state = const SendState();
}


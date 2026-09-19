import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_locale.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/app_settings.dart' show AppSettings, ThemePreference;
import '../../data/models/chain.dart';
import '../../data/models/security_settings.dart';
import '../../data/security/vault.dart';
import '../../data/waku/node_probe.dart' show NodeStatus;
import '../../shared/feedback.dart';
import '../../shared/layout.dart';
import '../../shared/widgets.dart';
import '../../state/controllers.dart';
import '../security/password_fields.dart';

/// 設定頁：外觀、語言、網路、身份與進階選項。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _rpcUrl;
  late final TextEditingController _tronRpcUrl;
  late final TextEditingController _besuRpcUrl;
  bool _resyncing = false;
  bool _probing = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _rpcUrl = TextEditingController(text: settings.rpcUrl);
    _tronRpcUrl = TextEditingController(text: settings.tronRpcUrl);
    _besuRpcUrl = TextEditingController(text: settings.besuRpcUrl);
  }

  @override
  void dispose() {
    _rpcUrl.dispose();
    _tronRpcUrl.dispose();
    _besuRpcUrl.dispose();
    super.dispose();
  }

  /// 重新探測所有節點的連線狀態。
  Future<void> _recheckNodes() async {
    setState(() => _probing = true);
    ref.invalidate(nodeStatusProvider);
    try {
      await ref.read(nodeStatusProvider.future);
      ref.invalidate(networkStatusProvider);
    } catch (_) {
      // 探測失敗只反映在清單狀態上，這裡不再額外提示。
    } finally {
      if (mounted) setState(() => _probing = false);
    }
  }

  /// 新增自訂節點。
  Future<void> _addNode() async {
    final s = context.s;
    final controller = TextEditingController();
    String? error;

    final added = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(s.settingsNodeAddTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: s.settingsWakuNode,
              hintText: s.settingsNodeAddHint,
              errorText: error,
              prefixIcon: const Icon(Icons.hub_rounded),
            ),
            onChanged: (_) {
              if (error != null) setDialogState(() => error = null);
            },
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.cancel),
            ),
            FilledButton(
              onPressed: () async {
                final code = await ref
                    .read(settingsProvider.notifier)
                    .addNode(controller.text);
                if (!context.mounted) return;
                if (code != null) {
                  setDialogState(() {
                    error = code == 'duplicate'
                        ? s.settingsNodeDuplicate
                        : s.settingsNodeInvalid;
                  });
                  return;
                }
                Navigator.pop(context, true);
              },
              child: Text(s.save),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    if (added != true || !mounted) return;
    await _recheckNodes();
    if (!mounted) return;
    showAppSnack(context, s.settingsNodeAdded);
  }

  /// 移除自訂節點（內建節點不可移除）。
  Future<void> _removeNode(String url) async {
    final s = context.s;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(s.settingsNodeRemove),
            content: Text(s.settingsNodeRemoveConfirm(url)),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(s.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  s.delete,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    await ref.read(settingsProvider.notifier).removeNode(url);
    await _recheckNodes();
  }

  /// 從節點 store 重新補拉最近錯過的訊息與金鑰包。
  Future<void> _resync() async {
    setState(() => _resyncing = true);
    try {
      await ref.read(chatControllerProvider.notifier).resyncHistory();
      await ref.read(contactsProvider.notifier).refreshKeys();
    } finally {
      if (mounted) setState(() => _resyncing = false);
    }
    if (!mounted) return;
    showAppSnack(context, context.s.settingsResyncDone);
  }

  /// 以私鑰取代目前身份：先警告後輸入，成功則提示並要求重新發布金鑰。
  ///
  /// 換身份會讓 DID 改變，舊對話不會消失但對方需要重新認識新 DID，因此這裡
  /// 明確告知使用者。
  ///
  /// 這個方法只使用 [State.context]（不接收 context 參數），讓 `mounted`
  /// 守衛與實際使用的 context 保持一致。
  Future<void> _confirmImportPrivateKey() async {
    final s = context.s;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(s.importPrivateKeyTitle),
            content: Text(s.importPrivateKeyWarn),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(s.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(s.next),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    final controller = TextEditingController();
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    var obscure = true;
    String? error;
    String? passwordError;
    var busy = false;

    // 用 StatefulBuilder 讓對話框內部能自行 setState（輸入驗證 / 載入狀態）。
    final imported = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> submit() async {
            // 新的身份必須有密碼保護 —— 否則等於又把私鑰明文寫回本地儲存。
            final passwordCode = validateNewPassword(
              password: passwordController.text,
              confirm: confirmController.text,
            );
            if (passwordCode != null) {
              setDialogState(() => passwordError = passwordCode);
              return;
            }
            setDialogState(() {
              busy = true;
              error = null;
              passwordError = null;
            });
            final failure = await ref
                .read(sessionProvider.notifier)
                .importPrivateKey(
                  controller.text,
                  password: passwordController.text,
                );
            if (!context.mounted) return;
            if (failure != null) {
              setDialogState(() {
                busy = false;
                error = failure == 'invalid-private-key'
                    ? s.importPrivateKeyInvalid
                    : s.importFailed;
              });
              return;
            }
            Navigator.pop(context, true);
          }

          return AlertDialog(
            title: Text(s.importPrivateKeyLabel),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: controller,
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  obscureText: obscure,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13.5,
                  ),
                  onChanged: (_) {
                    if (error != null) setDialogState(() => error = null);
                  },
                  decoration: InputDecoration(
                    hintText: s.importPrivateKeyHint,
                    errorText: error,
                    suffixIcon: IconButton(
                      tooltip: obscure ? s.reveal : s.hide,
                      onPressed: () =>
                          setDialogState(() => obscure = !obscure),
                      icon: Icon(
                        obscure
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                PasswordSetupFields(
                  passwordController: passwordController,
                  confirmController: confirmController,
                  passwordError: passwordError == null
                      ? null
                      : passwordErrorText(context, passwordError),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(context, false),
                child: Text(s.cancel),
              ),
              FilledButton(
                onPressed: busy ? null : submit,
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(s.importAction),
              ),
            ],
          );
        },
      ),
    );

    controller.dispose();
    passwordController.dispose();
    confirmController.dispose();
    if (imported != true || !mounted) return;

    // 新身份的金鑰包需重新發布，否則聯絡人無法加密訊息給自己。
    await ref.read(chatControllerProvider.notifier).publishKeys();
    if (!mounted) return;
    showAppSnack(context, s.restoreSuccess);
    ref.invalidate(contactsProvider);
    ref.invalidate(networkStatusProvider);
  }

  /// 選擇閒置多久後自動鎖定。
  Future<void> _pickAutoLock(int current) async {
    final s = context.s;
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text(
                s.securityAutoLock,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            for (final minutes in SecuritySettings.autoLockOptions)
              ListTile(
                title: Text(
                  minutes <= 0
                      ? s.securityAutoLockNever
                      : s.securityAutoLockMinutes('$minutes'),
                ),
                trailing: minutes == current
                    ? const Icon(Icons.check_rounded, color: AppColors.brand)
                    : null,
                onTap: () => Navigator.pop(sheetContext, minutes),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    await ref.read(securityProvider.notifier).setAutoLockMinutes(selected);
  }

  /// 修改保險庫密碼（需先驗證目前密碼）。
  Future<void> _changePassword() async {
    final s = context.s;
    final request = await showDialog<_PasswordChangeRequest>(
      context: context,
      builder: (dialogContext) => const _ChangePasswordDialog(),
    );
    if (request == null || !mounted) return;

    try {
      await ref.read(coreProvider).changePassword(
            currentPassword: request.current,
            newPassword: request.next,
          );
      if (!mounted) return;
      showAppSnack(context, s.passwordChanged);
    } on VaultException catch (error) {
      if (!mounted) return;
      showAppSnack(
        context,
        error.code == 'bad-password'
            ? s.passwordWrong
            : s.changePasswordFailed,
        danger: true,
      );
    } catch (_) {
      if (!mounted) return;
      showAppSnack(context, s.changePasswordFailed, danger: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final settings = ref.watch(settingsProvider);
    final locale = ref.watch(localeProvider);
    final security = ref.watch(securityProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ContentColumn(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: <Widget>[
              PageHeader(
                title: s.settingsTitle,
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
              ),
              // ------------------------------------------------------- 外觀
              SectionCard(
                title: s.settingsAppearance,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: ThemeOptionCard(
                            label: s.settingsThemeLight,
                            icon: Icons.light_mode_rounded,
                            selected: settings.theme == ThemePreference.light,
                            onTap: () => ref
                                .read(settingsProvider.notifier)
                                .setTheme(ThemePreference.light),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ThemeOptionCard(
                            label: s.settingsThemeDark,
                            icon: Icons.dark_mode_rounded,
                            selected: settings.theme == ThemePreference.dark,
                            onTap: () => ref
                                .read(settingsProvider.notifier)
                                .setTheme(ThemePreference.dark),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ThemeOptionCard(
                            label: s.settingsThemeSystem,
                            icon: Icons.brightness_auto_rounded,
                            selected: settings.theme == ThemePreference.system,
                            onTap: () => ref
                                .read(settingsProvider.notifier)
                                .setTheme(ThemePreference.system),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // ------------------------------------------------------- 安全
              SectionCard(
                title: s.securitySection,
                child: Column(
                  children: <Widget>[
                    SettingsTile(
                      icon: Icons.lock_rounded,
                      title: s.securityLockNow,
                      subtitle: s.securityLockNowDesc,
                      onTap: () => ref.read(sessionProvider.notifier).lock(),
                    ),
                    SettingsTile(
                      icon: Icons.timer_outlined,
                      title: s.securityAutoLock,
                      subtitle: security.autoLockMinutes <= 0
                          ? s.securityAutoLockNever
                          : s.securityAutoLockMinutes(
                              '${security.autoLockMinutes}',
                            ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _pickAutoLock(security.autoLockMinutes),
                    ),
                    SettingsTile(
                      icon: Icons.visibility_off_outlined,
                      title: s.securityHideSecrets,
                      subtitle: s.securityHideSecretsDesc,
                      trailing: DropdownButton<int>(
                        value: security.hideSecretsAfterSeconds,
                        underline: const SizedBox.shrink(),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        items: <DropdownMenuItem<int>>[
                          for (final seconds in <int>[15, 30, 60, 120])
                            DropdownMenuItem<int>(
                              value: seconds,
                              child: Text('$seconds s'),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          ref
                              .read(securityProvider.notifier)
                              .setHideSecretsAfterSeconds(value);
                        },
                      ),
                    ),
                    SettingsTile(
                      icon: Icons.login_rounded,
                      title: s.securityLockOnHide,
                      subtitle: s.securityLockOnHideDesc,
                      trailing: Switch(
                        value: security.lockOnHide,
                        onChanged: (value) => ref
                            .read(securityProvider.notifier)
                            .setLockOnHide(value),
                      ),
                      onTap: () => ref
                          .read(securityProvider.notifier)
                          .setLockOnHide(!security.lockOnHide),
                    ),
                    SettingsTile(
                      icon: Icons.password_rounded,
                      title: s.securityChangePassword,
                      subtitle: s.securityChangePasswordDesc,
                      onTap: _changePassword,
                    ),
                  ],
                ),
              ),
              // ------------------------------------------------------- 語言
              SectionCard(
                title: s.settingsLanguage,
                child: Column(
                  children: <Widget>[
                    SettingsTile(
                      icon: Icons.translate_rounded,
                      title: s.settingsThemeSystem,
                      subtitle: s.settingsLanguage,
                      trailing: locale == null
                          ? const Icon(Icons.check_rounded,
                              color: AppColors.brand)
                          : null,
                      onTap: () =>
                          ref.read(settingsProvider.notifier).setLocaleCode(''),
                    ),
                    for (final item in AppLocale.values)
                      SettingsTile(
                        icon: Icons.language_rounded,
                        title: item.nativeName,
                        subtitle: item.englishName,
                        trailing: locale == item
                            ? const Icon(Icons.check_rounded,
                                color: AppColors.brand)
                            : null,
                        onTap: () => ref
                            .read(settingsProvider.notifier)
                            .setLocaleCode(item.code),
                      ),
                  ],
                ),
              ),
              // ------------------------------------------------------- 網路
              SectionCard(
                title: s.settingsNetwork,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            s.settingsWakuNode,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addNode,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(s.settingsNodeAdd),
                        ),
                      ],
                    ),
                    Text(
                      s.settingsNodesDesc,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.45,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // 節點清單：點選可切換「使用中」的節點；內建節點不可移除。
                    for (final url in settings.nodeUrls) ...<Widget>[
                      _NodeTile(
                        key: ValueKey<String>(url),
                        url: url,
                        active: url == settings.activeNodeUrl,
                        onSelect: () => ref
                            .read(settingsProvider.notifier)
                            .setActiveNode(url),
                        onRemove: AppSettings.isBuiltinNode(url)
                            ? null
                            : () => _removeNode(url),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _probing ? null : _recheckNodes,
                        icon: _probing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.network_check_rounded, size: 18),
                        label: Text(s.settingsWakuTest),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _resyncing ? null : _resync,
                        icon: _resyncing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sync_rounded, size: 18),
                        label: Text(s.settingsResync),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.settingsResyncDesc,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              // ------------------------------------------------------- 身份
              SectionCard(
                title: s.identityTitle,
                child: Column(
                  children: <Widget>[
                    SettingsTile(
                      icon: Icons.fingerprint_rounded,
                      title: s.identityDid,
                      subtitle: settings.nickname.isEmpty
                          ? s.settingsBackup
                          : settings.nickname,
                      onTap: () => context.push('/settings/identity'),
                    ),
                    SettingsTile(
                      icon: Icons.key_rounded,
                      title: s.settingsPublishKeys,
                      subtitle: 'Waku /nexuschat/1/keys/json',
                      onTap: () async {
                        await ref
                            .read(chatControllerProvider.notifier)
                            .publishKeys();
                        if (!context.mounted) return;
                        showAppSnack(context, s.settingsKeysPublished);
                      },
                    ),
                    SettingsTile(
                      icon: Icons.download_rounded,
                      title: s.importPrivateKeyTitle,
                      subtitle: s.importPrivateKeySubtitle,
                      onTap: _confirmImportPrivateKey,
                    ),
                  ],
                ),
              ),
              // ------------------------------------------------------- 區塊鏈
              SectionCard(
                title: s.walletChain,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: ThemeOptionCard(
                            label: s.chainEthereum,
                            icon: Icons.diamond_outlined,
                            selected: settings.chain == ChainType.ethereum,
                            onTap: () => ref
                                .read(settingsProvider.notifier)
                                .setChain(ChainType.ethereum),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ThemeOptionCard(
                            label: s.chainTron,
                            icon: Icons.offline_bolt_rounded,
                            selected: settings.chain == ChainType.tron,
                            onTap: () => ref
                                .read(settingsProvider.notifier)
                                .setChain(ChainType.tron),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ThemeOptionCard(
                            label: s.chainBesu,
                            icon: Icons.hub_outlined,
                            selected: settings.chain == ChainType.besu,
                            onTap: () => ref
                                .read(settingsProvider.notifier)
                                .setChain(ChainType.besu),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s.walletChainDesc,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              // ------------------------------------------------------- 進階
              SectionCard(
                title: s.settingsAdvanced,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: <Widget>[
                    TextField(
                      controller: switch (settings.chain) {
                        ChainType.ethereum => _rpcUrl,
                        ChainType.tron => _tronRpcUrl,
                        ChainType.besu => _besuRpcUrl,
                      },
                      autocorrect: false,
                      enableSuggestions: false,
                      onSubmitted: (value) =>
                          ref.read(settingsProvider.notifier).setRpcFor(
                                settings.chain,
                                value.trim(),
                              ),
                      decoration: InputDecoration(
                        labelText: switch (settings.chain) {
                          ChainType.ethereum => s.walletRpcUrl,
                          ChainType.tron => s.walletTronRpc,
                          ChainType.besu => s.walletBesuRpc,
                        },
                        prefixIcon: const Icon(Icons.cable_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final value = switch (settings.chain) {
                            ChainType.ethereum => _rpcUrl.text.trim(),
                            ChainType.tron => _tronRpcUrl.text.trim(),
                            ChainType.besu => _besuRpcUrl.text.trim(),
                          };
                          await ref
                              .read(settingsProvider.notifier)
                              .setRpcFor(settings.chain, value);
                          ref.invalidate(walletInfoProvider);
                        },
                        icon: const Icon(Icons.save_rounded, size: 18),
                        label: Text(s.save),
                      ),
                    ),
                  ],
                ),
              ),
              // ------------------------------------------------------- 關於
              SectionCard(
                title: s.settingsAbout,
                child: Column(
                  children: <Widget>[
                    const SettingsTile(
                      icon: Icons.info_outline_rounded,
                      title: 'NexusChat',
                      subtitle: 'Waku · did:ethr · AES-256-GCM',
                      onTap: null,
                    ),
                    SettingsTile(
                      icon: Icons.numbers_rounded,
                      title: s.settingsVersion,
                      subtitle: '1.0.0',
                      onTap: null,
                    ),
                  ],
                ),
              ),
              // ----------------------------------------------------- 危險區
              SectionCard(
                title: s.identityRisk,
                child: SettingsTile(
                  icon: Icons.delete_forever_rounded,
                  title: s.settingsDelete,
                  danger: true,
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(s.settingsDelete),
                            content: Text(s.settingsDeleteConfirm),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(s.cancel),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(
                                  s.delete,
                                  style: const TextStyle(color: AppColors.danger),
                                ),
                              ),
                            ],
                          ),
                        ) ??
                        false;
                    if (confirmed) {
                      await ref.read(sessionProvider.notifier).wipeIdentity();
                      if (context.mounted) context.go('/welcome');
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 修改密碼對話框的結果。
class _PasswordChangeRequest {
  const _PasswordChangeRequest({required this.current, required this.next});

  final String current;
  final String next;
}

/// 修改保險庫密碼：驗證目前密碼 → 設定新密碼。
class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final code = validateNewPassword(
      password: _next.text,
      confirm: _confirm.text,
    );
    if (code != null) {
      setState(() => _error = code);
      return;
    }
    Navigator.pop(
      context,
      _PasswordChangeRequest(current: _current.text, next: _next.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AlertDialog(
      title: Text(s.securityChangePassword),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            PasswordInput(
              controller: _current,
              autofocus: true,
              label: s.currentPassword,
            ),
            const SizedBox(height: 20),
            PasswordSetupFields(
              passwordController: _next,
              confirmController: _confirm,
              passwordError:
                  _error == null ? null : passwordErrorText(context, _error),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(s.confirm)),
      ],
    );
  }
}

/// 單一 Waku 節點的列表項：位址、連線狀態、是否使用中，以及（自訂節點的）移除按鈕。
///
/// 一次只連線一台節點，所以點選列表項就會切換實際連線的對象。
class _NodeTile extends ConsumerWidget {
  const _NodeTile({
    super.key,
    required this.url,
    required this.active,
    required this.onSelect,
    required this.onRemove,
  });

  final String url;

  /// 是否為目前使用中的節點。
  final bool active;

  /// 點選列表項時切換使用中的節點。
  final VoidCallback onSelect;

  /// 僅自訂節點會提供；內建節點傳入 null 表示不可移除。
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.s;
    final theme = Theme.of(context);
    final statuses = ref.watch(nodeStatusProvider);
    final builtin = AppSettings.isBuiltinNode(url);
    final byUrl = <String, NodeStatus>{
      for (final item in statuses.value ?? const <NodeStatus>[]) item.url: item,
    };
    final status = byUrl[url];

    final Color color;
    final String label;
    if (statuses.isLoading && status == null) {
      color = theme.colorScheme.onSurface.withValues(alpha: 0.45);
      label = s.settingsNodeChecking;
    } else if (status == null) {
      color = theme.colorScheme.onSurface.withValues(alpha: 0.45);
      label = s.settingsNodeChecking;
    } else if (status.ok && !status.relayReady) {
      // 可連線但沒有 peer：訊息其實送不出去，不該顯示成綠燈。
      color = AppColors.danger;
      label = status.latencyMs == null
          ? s.statusNoPeers
          : '${s.statusNoPeers} · ${status.latencyMs}ms';
    } else if (status.ok) {
      color = AppColors.success;
      label = status.latencyMs == null
          ? s.settingsWakuOk
          : '${s.settingsWakuOk} · ${status.latencyMs}ms';
    } else {
      color = AppColors.danger;
      label = s.settingsWakuFail;
    }

    return InkWell(
      onTap: active ? null : onSelect,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          color: active ? AppColors.brand.withValues(alpha: 0.08) : null,
          border: Border.all(
            color: active
                ? AppColors.brand
                : theme.colorScheme.onSurface.withValues(alpha: 0.12),
            width: active ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              active ? Icons.radio_button_checked_rounded : Icons.hub_rounded,
              size: 18,
              color: active ? AppColors.brand : color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: MonoText(
                          url,
                          maxLines: 1,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Pill(
                        label: builtin
                            ? s.settingsNodeBuiltin
                            : s.settingsNodeCustom,
                        color: builtin
                            ? AppColors.brand
                            : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: <Widget>[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (active) ...<Widget>[
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 13,
                          color: AppColors.brand,
                        ),
                        const SizedBox(width: 5),
                      ],
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: active ? AppColors.brand : color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onRemove != null)
              IconButton(
                tooltip: s.settingsNodeRemove,
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}

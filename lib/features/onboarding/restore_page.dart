import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/crypto/app_identity.dart';
import '../../data/crypto/did.dart';
import '../../state/controllers.dart';
import '../security/password_fields.dart';

/// 匯入既有身份：支援「助記詞」與「私鑰」兩種來源。
///
/// 兩者都走同一條身份管線（`SessionController`），差別只在於解出私鑰的方式：
/// - 助記詞 → BIP39/BIP32 派生 `m/44'/60'/0'/0/0`，身份可以再次用助記詞回復。
/// - 私鑰 → 直接使用，等於外部錢包的同一個帳戶；沒有助記詞可備份。
class RestorePage extends ConsumerStatefulWidget {
  const RestorePage({super.key});

  @override
  ConsumerState<RestorePage> createState() => _RestorePageState();
}

/// 匯入來源。
enum _ImportMode { mnemonic, privateKey }

class _RestorePageState extends ConsumerState<RestorePage> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final TextEditingController _passphraseController = TextEditingController();
  final TextEditingController _confirmPassphraseController =
      TextEditingController();

  _ImportMode _mode = _ImportMode.mnemonic;
  String? _error;
  String? _passwordError;
  String? _passphraseError;
  bool _busy = false;

  /// 私鑰模式下即時預覽解出的地址，讓使用者確認匯入的是哪個帳戶。
  String? _previewAddress;

  /// 私鑰輸入框是否為明文顯示。
  bool _obscure = true;

  /// 助記詞模式的地址預覽計時器：派生要做 PBKDF2，輸入時節流一下。
  Timer? _previewTimer;

  @override
  void dispose() {
    _previewTimer?.cancel();
    _controller.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _passphraseController.dispose();
    _confirmPassphraseController.dispose();
    super.dispose();
  }

  void _switchMode(_ImportMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _controller.clear();
      _error = null;
      _previewAddress = null;
      _passphraseError = null;
      _obscure = true;
    });
  }

  /// 助記詞模式：預覽「助記詞 + 目前短語」會導出的地址。
  ///
  /// 短語打錯不會有任何錯誤訊息，只會還原出另一個錢包 —— 地址預覽是唯一
  /// 能在匯入前發現的機會。
  void _schedulePreview() {
    _previewTimer?.cancel();
    _previewTimer = Timer(const Duration(milliseconds: 400), _derivePreview);
  }

  Future<void> _derivePreview() async {
    final text = _controller.text.trim();
    if (_mode != _ImportMode.mnemonic || text.isEmpty) {
      if (!mounted) return;
      setState(() => _previewAddress = null);
      return;
    }
    try {
      final identity = await AppIdentity.fromMnemonic(
        text,
        passphrase: _passphraseController.text,
      );
      if (!mounted) return;
      setState(() => _previewAddress = Did.eip55(identity.address));
    } catch (_) {
      // 助記詞還沒打完（或打錯）時只是沒有預覽，不必打擾使用者。
      if (!mounted) return;
      setState(() => _previewAddress = null);
    }
  }

  /// 私鑰模式的即時驗證：邊輸入邊顯示對應地址或錯誤。
  void _onChanged(String value) {
    if (_mode != _ImportMode.privateKey) {
      if (_error != null) setState(() => _error = null);
      _schedulePreview();
      return;
    }
    final text = value.trim();
    if (text.isEmpty) {
      setState(() {
        _error = null;
        _previewAddress = null;
      });
      return;
    }
    if (!AppIdentity.isValidPrivateKey(text)) {
      setState(() {
        _error = context.s.importPrivateKeyInvalid;
        _previewAddress = null;
      });
      return;
    }
    // 位址推導是純計算，量小到可以在輸入時同步做。
    setState(() {
      _error = null;
      _previewAddress = _deriveAddress(text);
    });
  }

  /// 由私鑰即時推導地址（比建立完整身份輕量：跳過 X25519 派生）。
  static String _deriveAddress(String privateHex) =>
      Did.eip55(AppIdentity.addressFromPrivateKey(privateHex));

  Future<void> _import() async {
    FocusScope.of(context).unfocus();

    // 先檢查密碼：沒有可用的保險庫密碼，身份就不該被匯入。
    final passwordCode = validateNewPassword(
      password: _passwordController.text,
      confirm: _confirmController.text,
    );
    if (passwordCode != null) {
      setState(() => _passwordError = passwordCode);
      return;
    }
    // 短語只在助記詞模式有意義，且打錯不會報錯 —— 要求輸入兩次。
    final passphrase = _passphraseController.text;
    if (_mode == _ImportMode.mnemonic &&
        passphrase != _confirmPassphraseController.text) {
      setState(() => _passphraseError = context.s.passphraseMismatch);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _passwordError = null;
      _passphraseError = null;
    });

    final notifier = ref.read(sessionProvider.notifier);
    final password = _passwordController.text;
    final failure = _mode == _ImportMode.mnemonic
        ? await notifier.restoreIdentity(
            _controller.text,
            password: password,
            passphrase: passphrase,
          )
        : await notifier.importPrivateKey(_controller.text, password: password);
    if (!mounted) return;

    if (failure != null) {
      setState(() {
        _busy = false;
        _error = _mode == _ImportMode.mnemonic
            ? context.s.restoreError
            : context.s.importPrivateKeyInvalid;
      });
      return;
    }

    setState(() => _busy = false);
    // 匯入後在背景發布金鑰包；離線也不阻塞進入主介面，連上網後會自動補發。
    unawaited(ref.read(chatControllerProvider.notifier).publishKeys());
    if (!mounted) return;
    context.go('/chats');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final isPrivateKey = _mode == _ImportMode.privateKey;

    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: () => context.go('/welcome'))),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    s.restoreTitle,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isPrivateKey ? s.importPrivateKeyDesc : s.restoreDesc,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // --------------------------------------------- 來源切換
                  _ModeSwitch(
                    mode: _mode,
                    onChanged: _switchMode,
                  ),
                  const SizedBox(height: 20),
                  // --------------------------------------------- 輸入區
                  if (isPrivateKey)
                    TextField(
                      controller: _controller,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.none,
                      obscureText: _obscure,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13.5,
                      ),
                      onChanged: _onChanged,
                      decoration: InputDecoration(
                        labelText: s.importPrivateKeyLabel,
                        hintText: s.importPrivateKeyHint,
                        errorText: _error,
                        prefixIcon: const Icon(Icons.key_rounded),
                        suffixIcon: IconButton(
                          tooltip: _obscure ? s.reveal : s.hide,
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                          ),
                        ),
                      ),
                    )
                  else
                    TextField(
                      controller: _controller,
                      maxLines: 4,
                      minLines: 3,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.none,
                      onChanged: _onChanged,
                      decoration: InputDecoration(
                        hintText: s.restoreHint,
                        errorText: _error,
                        alignLabelWithHint: true,
                      ),
                    ),
                  // ------------------------------------- 私鑰地址即時預覽
                  if (isPrivateKey && _previewAddress != null) ...<Widget>[
                    const SizedBox(height: 14),
                    _PreviewCard(address: _previewAddress!),
                  ],
                  // ----------------------------------- 助記詞的 BIP39 短語
                  if (!isPrivateKey) ...<Widget>[
                    const SizedBox(height: 6),
                    PassphraseFields(
                      controller: _passphraseController,
                      confirmController: _confirmPassphraseController,
                      errorText: _passphraseError,
                      onPreview: (_) => _schedulePreview(),
                      previewAddress: _previewAddress,
                    ),
                  ],
                  const SizedBox(height: 26),
                  // ------------------------------------- 保險庫密碼
                  Text(
                    s.passwordSetupTitle,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.passwordSetupDesc,
                    style: TextStyle(
                      fontSize: 12.8,
                      height: 1.45,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 14),
                  PasswordSetupFields(
                    passwordController: _passwordController,
                    confirmController: _confirmController,
                    passwordError: _passwordError == null
                        ? null
                        : passwordErrorText(context, _passwordError),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _busy ? null : _import,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(s.importAction),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        isPrivateKey
                            ? Icons.warning_amber_rounded
                            : Icons.shield_outlined,
                        size: 17,
                        color: isPrivateKey
                            ? AppColors.warning
                            : theme.colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isPrivateKey
                              ? s.importPrivateKeyWarn
                              : s.identityBackupDesc,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.45,
                            fontWeight:
                                isPrivateKey ? FontWeight.w600 : FontWeight.w400,
                            color: isPrivateKey
                                ? AppColors.warning
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 助記詞 / 私鑰 的來源切換器。
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.mode, required this.onChanged});

  final _ImportMode mode;
  final ValueChanged<_ImportMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: <Widget>[
          _Segment(
            label: s.importModeMnemonic,
            icon: Icons.text_snippet_outlined,
            selected: mode == _ImportMode.mnemonic,
            onTap: () => onChanged(_ImportMode.mnemonic),
          ),
          _Segment(
            label: s.importModePrivateKey,
            icon: Icons.key_rounded,
            selected: mode == _ImportMode.privateKey,
            onTap: () => onChanged(_ImportMode.privateKey),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 16,
                color: selected
                    ? AppColors.brand
                    : theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? AppColors.brand
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 私鑰對應地址的即時預覽。
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.check_circle_outline_rounded,
              size: 17, color: AppColors.success),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  s.importPrivateKeyAddress,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  address,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontFamily: 'monospace',
                    height: 1.4,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

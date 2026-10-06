import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/crypto/app_identity.dart';
import '../../shared/feedback.dart';
import '../../state/controllers.dart';
import '../security/password_fields.dart';

/// 建立身份的三步骤流程：产生助记词 → 验证备份 → 设定暱称。
class CreateIdentityPage extends ConsumerStatefulWidget {
  const CreateIdentityPage({super.key});

  @override
  ConsumerState<CreateIdentityPage> createState() =>
      _CreateIdentityPageState();
}

class _CreateIdentityPageState extends ConsumerState<CreateIdentityPage> {
  /// 步骤：0 助记词 → 1 验证备份 → 2 设定密码 → 3 暱称。
  static const int _stepCount = 4;

  int _step = 0;
  String _mnemonic = '';
  final TextEditingController _verifyController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final TextEditingController _passphraseController = TextEditingController();
  final TextEditingController _confirmPassphraseController =
      TextEditingController();
  int _verifyIndex = 0;
  String? _error;
  String? _passwordError;
  String? _passphraseError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    final identity = await AppIdentity.generate();
    if (!mounted) return;
    setState(() {
      _mnemonic = identity.mnemonic;
      _verifyIndex = 1 + (DateTime.now().millisecond % 12);
    });
  }

  @override
  void dispose() {
    _verifyController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _passphraseController.dispose();
    _confirmPassphraseController.dispose();
    super.dispose();
  }

  Future<void> _copyMnemonic() async {
    await Clipboard.setData(ClipboardData(text: _mnemonic));
    if (!mounted) return;
    showAppSnack(context, context.s.mnemonicCopied);
  }

  void _verify() {
    final words = _mnemonic.split(' ');
    final expected = words[_verifyIndex - 1].trim().toLowerCase();
    final actual = _verifyController.text.trim().toLowerCase();
    if (actual != expected) {
      setState(() => _error = context.s.verifyWrong);
      return;
    }
    setState(() {
      _error = null;
      _step = 2;
    });
  }

  /// 离开助记词步骤前先确认短语两次输入一致。
  ///
  /// 短语打错不会有任何错误讯息，只能靠「输入两次」挡下笔误。
  void _goToVerify() {
    if (_passphraseController.text != _confirmPassphraseController.text) {
      setState(() => _passphraseError = context.s.passphraseMismatch);
      return;
    }
    setState(() {
      _passphraseError = null;
      _step = 1;
    });
  }

  void _setPassword() {
    final code = validateNewPassword(
      password: _passwordController.text,
      confirm: _confirmController.text,
    );
    if (code != null) {
      setState(() => _passwordError = code);
      return;
    }
    setState(() {
      _passwordError = null;
      _step = 3;
    });
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    try {
      // 以「先前显示并已验证过的助记词」建立身份。
      //
      // 注意：这里必须走 restore（由助记词派生），而不是 create 重新生成 ——
      // 重新生成会得到一组完全不同的助记词，让使用者备份到无法还原的字串。
      final failure = await ref.read(sessionProvider.notifier).restoreIdentity(
            _mnemonic,
            password: _passwordController.text,
            // 助记词配上短语才等于这个身份；建立后就固定下来。
            passphrase: _passphraseController.text,
          );
      if (failure != null) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _step = 2;
          _passwordError = 'create-failed';
        });
        return;
      }
      final name = _nameController.text.trim();
      if (name.isNotEmpty) {
        await ref.read(settingsProvider.notifier).setNickname(name);
      }
      await ref.read(settingsProvider.notifier).setOnboarded(true);
      // 后台发布金钥包；离线也不阻塞进入主介面，连上网后会自动补发。
      unawaited(ref.read(chatControllerProvider.notifier).publishKeys());
      if (!mounted) return;
      context.go('/chats');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/welcome')),
        title: Row(
          children: <Widget>[
            for (var i = 0; i < _stepCount; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                margin: const EdgeInsets.only(right: 6),
                width: i == _step ? 22 : 8,
                height: 6,
                decoration: BoxDecoration(
                  color: i <= _step
                      ? AppColors.brand
                      : theme.colorScheme.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
          ],
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: switch (_step) {
                  0 => _MnemonicStep(
                      key: const ValueKey('mnemonic'),
                      mnemonic: _mnemonic,
                      onCopy: _copyMnemonic,
                      passphraseController: _passphraseController,
                      confirmPassphraseController:
                          _confirmPassphraseController,
                      passphraseError: _passphraseError,
                      onNext: _goToVerify,
                    ),
                  1 => _VerifyStep(
                      key: const ValueKey('verify'),
                      index: _verifyIndex,
                      controller: _verifyController,
                      error: _error,
                      onVerify: _verify,
                    ),
                  2 => _SecurityStep(
                      key: const ValueKey('security'),
                      passwordController: _passwordController,
                      confirmController: _confirmController,
                      errorCode: _passwordError,
                      onNext: _setPassword,
                    ),
                  _ => _ProfileStep(
                      key: const ValueKey('profile'),
                      controller: _nameController,
                      busy: _busy,
                      onFinish: _finish,
                    ),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 第一步：助记词 + （选填）BIP39 密码短语。
///
/// 短语放在助记词旁边是有理由的：两者共同决定身份，备份时本来就该一起抄，
/// 拆到后面使用者很容易只备份一半。
class _MnemonicStep extends StatelessWidget {
  const _MnemonicStep({
    required this.mnemonic,
    required this.onCopy,
    required this.passphraseController,
    required this.confirmPassphraseController,
    required this.passphraseError,
    required this.onNext,
    super.key,
  });

  final String mnemonic;
  final VoidCallback onCopy;
  final TextEditingController passphraseController;
  final TextEditingController confirmPassphraseController;
  final String? passphraseError;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final words = mnemonic.isEmpty
        ? <String>[]
        : mnemonic.split(' ').toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          s.mnemonicTitle,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          s.mnemonicDesc,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
          ),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
            ),
            color: theme.colorScheme.onSurface.withValues(alpha: 0.03),
          ),
          child: words.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    // 每行固定 3 个：宽度要用**实际可用宽度**来算，不能拿
                    // MediaQuery 的萤幕宽度 —— 桌机上内容会被 maxWidth 收窄，
                    // 两者不相等，照萤幕宽算会挤成每行 2 个。
                    const int perRow = 3;
                    const double spacing = 8;
                    final itemWidth =
                        (constraints.maxWidth - spacing * (perRow - 1)) /
                            perRow;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: <Widget>[
                        for (var i = 0; i < words.length; i++)
                          Container(
                            width: itemWidth,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.08),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.35),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    words[i],
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                s.mnemonicWarn,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        // ------------------------------------------ 选填的 BIP39 密码短语
        const SizedBox(height: 8),
        PassphraseFields(
          controller: passphraseController,
          confirmController: confirmPassphraseController,
          errorText: passphraseError,
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_all_rounded),
                label: Text(s.copy),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: words.isEmpty ? null : onNext,
                child: Text(s.mnemonicNext),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VerifyStep extends StatelessWidget {
  const _VerifyStep({
    required this.index,
    required this.controller,
    required this.error,
    required this.onVerify,
    super.key,
  });

  final int index;
  final TextEditingController controller;
  final String? error;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          s.verifyTitle,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          s.verifyDesc('$index'),
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.none,
          onSubmitted: (_) => onVerify(),
          decoration: InputDecoration(
            hintText: s.verifyPlaceholder('$index'),
            errorText: error,
          ),
        ),
        const SizedBox(height: 22),
        FilledButton(onPressed: onVerify, child: Text(s.next)),
      ],
    );
  }
}

/// 第三步：设定本地保险库密码。
///
/// 密码是这个威胁模型下唯一有效的防线 —— Web 端没有可信任的硬体金钥储存，
/// 任何「应用能自动解开」的方案，能执行脚本的攻击者都能照样解开。
class _SecurityStep extends StatelessWidget {
  const _SecurityStep({
    required this.passwordController,
    required this.confirmController,
    required this.errorCode,
    required this.onNext,
    super.key,
  });

  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final String? errorCode;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final errorText = switch (errorCode) {
      'create-failed' => s.createFailed,
      null => null,
      _ => passwordErrorText(context, errorCode),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          s.passwordSetupTitle,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          s.passwordSetupDesc,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: AppColors.warning.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: AppColors.warning,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  s.passwordForgotWarn,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        PasswordSetupFields(
          passwordController: passwordController,
          confirmController: confirmController,
          autofocus: true,
          passwordError: errorText,
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: onNext, child: Text(s.next)),
      ],
    );
  }
}

class _ProfileStep extends StatelessWidget {
  const _ProfileStep({
    required this.controller,
    required this.busy,
    required this.onFinish,
    super.key,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          s.profileTitle,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          s.profileDesc,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: s.displayName,
            hintText: s.displayNameHint,
            prefixIcon: const Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: 26),
        FilledButton(
          onPressed: busy ? null : onFinish,
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(s.enterApp),
        ),
      ],
    );
  }
}

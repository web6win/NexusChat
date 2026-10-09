import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/security/vault.dart';

/// 密码输入框（含明码切换与密码管理器提示）。
class PasswordInput extends StatefulWidget {
  const PasswordInput({
    required this.controller,
    this.label,
    this.hintText,
    this.errorText,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.enabled = true,
    super.key,
  });

  final TextEditingController controller;
  final String? label;
  final String? hintText;
  final String? errorText;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final bool enabled;

  @override
  State<PasswordInput> createState() => _PasswordInputState();
}

class _PasswordInputState extends State<PasswordInput> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return TextField(
      controller: widget.controller,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      obscureText: _obscure,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hintText,
        errorText: widget.errorText,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: _obscure ? s.reveal : s.hide,
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(
            _obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            size: 20,
          ),
        ),
      ),
    );
  }
}

/// 密码强度指示条。
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({required this.password, super.key});

  final String password;

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    final s = context.s;
    final theme = Theme.of(context);
    final strength = PasswordPolicy.evaluate(password);

    final color = switch (strength.score) {
      0 || 1 => AppColors.danger,
      2 => AppColors.warning,
      3 => AppColors.accent,
      _ => AppColors.success,
    };
    final label = switch (strength.label) {
      'strong' => s.passwordStrong,
      'good' => s.passwordGood,
      'fair' => s.passwordFair,
      _ => s.passwordWeak,
    };
    // score 0~4 映射到 1~4 格。
    final filled = strength.score <= 0 ? 1 : strength.score;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              for (var i = 0; i < 4; i++)
                Expanded(
                  child: Container(
                    height: 5,
                    margin: EdgeInsets.only(right: i == 3 ? 0 : 5),
                    decoration: BoxDecoration(
                      color: i < filled
                          ? color
                          : theme.colorScheme.onSurface.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            s.passwordRule,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// 「设定新密码」的输入组：新密码 + 确认密码 + 强度提示。
class PasswordSetupFields extends StatefulWidget {
  const PasswordSetupFields({
    required this.passwordController,
    required this.confirmController,
    this.autofocus = false,
    this.confirmError,
    this.passwordError,
    super.key,
  });

  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final bool autofocus;
  final String? confirmError;
  final String? passwordError;

  @override
  State<PasswordSetupFields> createState() => _PasswordSetupFieldsState();
}

class _PasswordSetupFieldsState extends State<PasswordSetupFields> {
  @override
  void initState() {
    super.initState();
    widget.passwordController.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.passwordController.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PasswordInput(
          controller: widget.passwordController,
          autofocus: widget.autofocus,
          label: s.passwordLabel,
          hintText: s.passwordHint,
          errorText: widget.passwordError,
        ),
        PasswordStrengthMeter(password: widget.passwordController.text),
        const SizedBox(height: 16),
        PasswordInput(
          controller: widget.confirmController,
          label: s.passwordConfirmLabel,
          errorText: widget.confirmError,
        ),
      ],
    );
  }
}

/// BIP39 密码短语（第 13 / 25 个词）的输入组。
///
/// 这是进阶功能，多数人用不到，预设收起以免占住版面；标题（含钥匙图示）
/// 仍然固定显示，需要的时候点一下就展开。
///
/// 短语没有「强度」可言（任何字串都合法），但**打错不会有任何错误提示** ——
/// 只会还原出另一个身份，所以一定要输入两次并显示警告。
class PassphraseFields extends StatefulWidget {
  const PassphraseFields({
    required this.controller,
    required this.confirmController,
    this.errorText,
    this.onPreview,
    this.previewAddress,
    this.initiallyExpanded = false,
    super.key,
  });

  final TextEditingController controller;
  final TextEditingController confirmController;
  final String? errorText;

  /// 输入变动时的回呼（让呼叫端更新地址预览）。
  final ValueChanged<String>? onPreview;

  /// 由「助记词 + 目前短语」派生出的地址；还原时用它核对短语有没有打错。
  final String? previewAddress;

  /// 是否预设展开。
  final bool initiallyExpanded;

  @override
  State<PassphraseFields> createState() => _PassphraseFieldsState();
}

class _PassphraseFieldsState extends State<PassphraseFields> {
  final ExpansibleController _tile = ExpansibleController();

  @override
  void didUpdateWidget(PassphraseFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 错误藏在收起的面板里就等于没有提示 —— 出现错误时自动展开。
    final appeared =
        oldWidget.errorText == null && widget.errorText != null;
    if (appeared) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tile.expand();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    return ExpansionTile(
      controller: _tile,
      tilePadding: EdgeInsets.zero,
      initiallyExpanded: widget.initiallyExpanded,
      title: Row(
        children: <Widget>[
          Icon(Icons.key_rounded, size: 17, color: AppColors.brand),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              s.passphraseAdvanced,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      children: <Widget>[
        const SizedBox(height: 4),
        Text(
          s.passphraseDesc,
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 14),
        PasswordInput(
          controller: widget.controller,
          label: s.passphraseLabel,
          hintText: s.passphraseHint,
          onChanged: widget.onPreview,
        ),
        const SizedBox(height: 14),
        PasswordInput(
          controller: widget.confirmController,
          label: s.passphraseConfirmLabel,
          hintText: s.passphraseHint,
          errorText: widget.errorText,
        ),
        if (widget.previewAddress != null) ...<Widget>[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.account_circle_outlined,
                  size: 16, color: AppColors.brand),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.previewAddress!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

/// 检查「新密码 + 确认」是否可提交。
///
/// 回传错误代码，或 `null` 表示合法。
String? validateNewPassword({
  required String password,
  required String confirm,
}) {
  final strength = PasswordPolicy.evaluate(password);
  if (!strength.isAcceptable) return 'weak-password';
  if (password != confirm) return 'password-mismatch';
  return null;
}

/// 把错误代码转成可读文案。
String passwordErrorText(BuildContext context, String? code) {
  final s = context.s;
  return switch (code) {
    'weak-password' => s.passwordWeakError,
    'password-mismatch' => s.passwordMismatch,
    _ => '',
  };
}

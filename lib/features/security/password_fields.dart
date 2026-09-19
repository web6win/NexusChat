import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/security/vault.dart';

/// 密碼輸入框（含明碼切換與密碼管理器提示）。
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

/// 密碼強度指示條。
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

/// 「設定新密碼」的輸入組：新密碼 + 確認密碼 + 強度提示。
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

/// 檢查「新密碼 + 確認」是否可提交。
///
/// 回傳錯誤代碼，或 `null` 表示合法。
String? validateNewPassword({
  required String password,
  required String confirm,
}) {
  final strength = PasswordPolicy.evaluate(password);
  if (!strength.isAcceptable) return 'weak-password';
  if (password != confirm) return 'password-mismatch';
  return null;
}

/// 把錯誤代碼轉成可讀文案。
String passwordErrorText(BuildContext context, String? code) {
  final s = context.s;
  return switch (code) {
    'weak-password' => s.passwordWeakError,
    'password-mismatch' => s.passwordMismatch,
    _ => '',
  };
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../state/controllers.dart';
import 'password_fields.dart';

/// 舊版明文身份的一次性遷移頁。
///
/// 舊版本把助記詞與私鑰以明文寫進本地儲存。這個頁面強制使用者設定密碼，
/// 完成後明文會被刪除、改為加密保險庫。
///
/// **刻意不提供「稍後再說」** —— 只要還留著明文，任何能讀取本機儲存的
/// 程式都能直接拿走助記詞，那正是這次改造要消滅的風險。
class MigrateVaultPage extends ConsumerStatefulWidget {
  const MigrateVaultPage({super.key});

  @override
  ConsumerState<MigrateVaultPage> createState() => _MigrateVaultPageState();
}

class _MigrateVaultPageState extends ConsumerState<MigrateVaultPage> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool _busy = false;
  String? _errorCode;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = validateNewPassword(
      password: _password.text,
      confirm: _confirm.text,
    );
    if (code != null) {
      setState(() => _errorCode = code);
      return;
    }
    setState(() {
      _errorCode = null;
      _busy = true;
    });

    final failure =
        await ref.read(sessionProvider.notifier).migrateToVault(_password.text);
    if (!mounted) return;
    setState(() => _busy = false);

    if (failure == null) {
      context.go('/chats');
      return;
    }
    setState(() => _errorCode = 'migrate-failed');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final errorText = switch (_errorCode) {
      'migrate-failed' => s.migrateFailed,
      null => null,
      _ => passwordErrorText(context, _errorCode),
    };

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.enhanced_encryption_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    s.migrateTitle,
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    s.migrateDesc,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.55,
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
                    passwordController: _password,
                    confirmController: _confirm,
                    autofocus: true,
                    passwordError: errorText,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(s.migrateAction),
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

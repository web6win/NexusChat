import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/security_settings.dart';
import '../../data/security/vault.dart';
import '../../shared/feedback.dart';
import '../../shared/layout.dart';
import '../../shared/widgets.dart';
import '../../state/controllers.dart';
import '../security/password_fields.dart';

/// 安全与隐私：立即锁定、闲置自动锁、隐藏密钥倒数、切到背景锁定、修改密码。
/// 拆自原本挤在同一页的设定。
class SecuritySettingsPage extends ConsumerStatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  ConsumerState<SecuritySettingsPage> createState() =>
      _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends ConsumerState<SecuritySettingsPage> {
  /// 选择闲置多久后自动锁定。
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

  /// 修改保险库密码（需先验证目前密码）。
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
    final security = ref.watch(securityProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.securitySection)),
      body: SafeArea(
        bottom: false,
        child: ContentColumn(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: <Widget>[
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
            ],
          ),
        ),
      ),
    );
  }
}

/// 修改密码对话框的结果。
class _PasswordChangeRequest {
  const _PasswordChangeRequest({required this.current, required this.next});

  final String current;
  final String next;
}

/// 修改保险库密码：验证目前密码 → 设定新密码。
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

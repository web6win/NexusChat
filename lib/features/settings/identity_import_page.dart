import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../shared/feedback.dart';
import '../../shared/layout.dart';
import '../../shared/widgets.dart';
import '../../state/controllers.dart';
import '../security/password_fields.dart';

/// 身份管理：检视 / 备份身份，以及以私钥取代目前的身份。
/// 拆自原本挤在同一页的「身份」区块。
class IdentityImportPage extends ConsumerStatefulWidget {
  const IdentityImportPage({super.key});

  @override
  ConsumerState<IdentityImportPage> createState() => _IdentityImportPageState();
}

class _IdentityImportPageState extends ConsumerState<IdentityImportPage> {
  /// 以私钥取代目前身份：先警告后输入，成功则提示并要求重新发布金钥。
  ///
  /// 换身份会让 DID 改变，旧对话不会消失但对方需要重新认识新 DID，因此这里
  /// 明确告知使用者。
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

    // 用 StatefulBuilder 让对话框内部能自行 setState（输入验证 / 载入状态）。
    final imported = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> submit() async {
            // 新的身份必须有密码保护 —— 否则等于又把私钥明文写回本地储存。
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

    // 新身份的金钥包需重新发布，否则联络人无法加密讯息给自己。
    await ref.read(chatControllerProvider.notifier).publishKeys();
    if (!mounted) return;
    showAppSnack(context, s.restoreSuccess);
    ref.invalidate(contactsProvider);
    ref.invalidate(networkStatusProvider);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final nickname = ref.watch(settingsProvider).nickname;

    return Scaffold(
      appBar: AppBar(title: Text(s.identityTitle)),
      body: SafeArea(
        bottom: false,
        child: ContentColumn(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: <Widget>[
              SectionCard(
                title: s.identityTitle,
                child: Column(
                  children: <Widget>[
                    SettingsTile(
                      icon: Icons.fingerprint_rounded,
                      title: nickname.isEmpty ? s.identityTitle : nickname,
                      subtitle: s.settingsBackup,
                      onTap: () => context.push('/settings/identity'),
                    ),
                    SettingsTile(
                      icon: Icons.key_rounded,
                      title: s.importPrivateKeyTitle,
                      subtitle: s.importPrivateKeySubtitle,
                      onTap: _confirmImportPrivateKey,
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

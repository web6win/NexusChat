import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/strings.dart';
import '../shared/feedback.dart';
import '../state/controllers.dart';

/// 签名 / 汇出敏感资料前的密码二次校验。
///
/// App 解锁后私钥常驻内存，仅靠确认弹窗即可签章。这里在真正动用私钥之前
/// 再要一次密码，避免使用者离开座位时页面静默代签（类似 TronLink 的
/// 每次签名都要密码 / 生物识别）。
///
/// 通过回传 `true`；取消或密码错误回传 `false`。[title] / [desc] 不传时
/// 套用「签名验证」文案，汇出流程可传入专属文案。
Future<bool> authorizeWithPassword(
  BuildContext context,
  WidgetRef ref, {
  String? title,
  String? desc,
}) async {
  final s = context.s;
  final password = await showDialog<String>(
    context: context,
    builder: (dialogContext) => PasswordPromptDialog(
      title: title ?? s.signVerifyTitle,
      desc: desc ?? s.signVerifyDesc,
    ),
  );
  if (password == null || password.isEmpty) return false;
  final ok = await ref.read(coreProvider).verifyPassword(password);
  if (!context.mounted) return false;
  if (!ok) {
    if (context.mounted) showAppSnack(context, s.passwordWrong, danger: true);
    return false;
  }
  return true;
}

/// 敏感操作前的密码验证对话框。回传输入的密码；取消回传 `null`。
class PasswordPromptDialog extends StatefulWidget {
  const PasswordPromptDialog({required this.title, required this.desc, super.key});

  final String title;
  final String desc;

  @override
  State<PasswordPromptDialog> createState() => _PasswordPromptDialogState();
}

class _PasswordPromptDialogState extends State<PasswordPromptDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text);

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            widget.desc,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: true,
            decoration: InputDecoration(
              labelText: s.passwordLabel,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
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

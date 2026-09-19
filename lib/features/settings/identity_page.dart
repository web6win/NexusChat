import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/crypto/did.dart';
import '../../shared/feedback.dart';
import '../../shared/layout.dart';
import '../../shared/widgets.dart';
import '../../state/controllers.dart';
import '../security/password_fields.dart';

/// 身份頁：DID 細節與助記詞備份。
///
/// 顯示助記詞或私鑰**必須先輸入密碼**，且顯示後會倒數自動隱藏 ——
/// 避免有人在你離開座位時直接打開這個頁面抄走助記詞。
class IdentityPage extends ConsumerStatefulWidget {
  const IdentityPage({super.key});

  @override
  ConsumerState<IdentityPage> createState() => _IdentityPageState();
}

class _IdentityPageState extends ConsumerState<IdentityPage> {
  bool _revealed = false;
  Timer? _hideTimer;
  int _hideLeft = 0;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    showAppSnack(context, context.s.copied);
  }

  /// 切換敏感內容的顯示狀態。
  ///
  /// 由隱藏轉為顯示時要求重新輸入密碼；由顯示轉為隱藏則直接關閉。
  Future<void> _toggleReveal() async {
    if (_revealed) {
      _hideTimer?.cancel();
      setState(() {
        _revealed = false;
        _hideLeft = 0;
      });
      return;
    }

    final s = context.s;
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _PasswordPromptDialog(
        title: s.exportVerifyTitle,
        desc: s.exportVerifyDesc,
      ),
    );
    if (password == null || password.isEmpty) return;

    final ok = await ref.read(coreProvider).verifyPassword(password);
    if (!mounted) return;
    if (!ok) {
      showAppSnack(context, s.passwordWrong, danger: true);
      return;
    }
    _showSecrets();
  }

  /// 顯示敏感內容並啟動自動隱藏倒數。
  void _showSecrets() {
    final seconds = ref.read(securityProvider).hideSecretsAfterSeconds;
    _hideTimer?.cancel();
    setState(() {
      _revealed = true;
      _hideLeft = seconds;
    });
    _hideTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _hideLeft--);
      if (_hideLeft <= 0) {
        timer.cancel();
        setState(() => _revealed = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final identity = ref.watch(sessionProvider).identity;

    if (identity == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('--')),
      );
    }

    final mnemonicWords = identity.mnemonic.isEmpty
        ? <String>[]
        : identity.mnemonic.split(' ');

    return Scaffold(
      appBar: AppBar(title: Text(s.identityTitle)),
      body: SafeArea(
        child: ContentColumn(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: <Widget>[
              // ------------------------------------------------------ 身份卡
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            Icons.fingerprint_rounded,
                            color: Colors.white,
                            size: 25,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                ref.watch(settingsProvider).nickname.isEmpty
                                    ? s.identityTitle
                                    : ref.watch(settingsProvider).nickname,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'did:ethr · ${s.identityMethod}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      s.identityDid,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      identity.did,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontFamily: 'monospace',
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                              minimumSize: const Size.fromHeight(44),
                            ),
                            onPressed: () => _copy(identity.did),
                            icon: const Icon(Icons.copy_rounded, size: 17),
                            label: Text(s.copy),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.brand,
                              minimumSize: const Size.fromHeight(44),
                            ),
                            onPressed: () async {
                              await ref
                                  .read(chatControllerProvider.notifier)
                                  .publishKeys();
                              if (!context.mounted) return;
                              showAppSnack(context, s.settingsKeysPublished);
                            },
                            icon: const Icon(Icons.publish_rounded, size: 17),
                            label: Text(s.settingsPublishKeys),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ------------------------------------------------------ 金鑰
              SectionCard(
                title: s.identityEncKey,
                child: Column(
                  children: <Widget>[
                    SettingsTile(
                      icon: Icons.account_circle_outlined,
                      title: s.identityEthAddress,
                      subtitle: Did.eip55(identity.address),
                      onTap: () => _copy(Did.eip55(identity.address)),
                    ),
                    SettingsTile(
                      icon: Icons.draw_outlined,
                      title: s.identitySignKey,
                      subtitle: '${identity.ethPublicHex.substring(0, 26)}…',
                      onTap: () => _copy(identity.ethPublicHex),
                    ),
                    SettingsTile(
                      icon: Icons.enhanced_encryption_rounded,
                      title: s.identityEncKey,
                      subtitle: identity.encPublicKeyB64,
                      onTap: () => _copy(identity.encPublicKeyB64),
                    ),
                    // 私鑰匯入的身份可直接複製私鑰做備份（助記詞身份則靠助記詞）。
                    if (!identity.hasMnemonic)
                      SettingsTile(
                        icon: Icons.key_rounded,
                        title: s.importPrivateKeyLabel,
                        subtitle: _revealed
                            ? identity.ethPrivateHex
                            : '${identity.ethPrivateHex.substring(0, 12)}'
                                '${'•' * 16}',
                        onTap: () => _revealed
                            ? _copy(identity.ethPrivateHex)
                            : _toggleReveal(),
                      ),
                  ],
                ),
              ),
              // ------------------------------------------------------ 備份
              SectionCard(
                title: s.identityBackup,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(Icons.shield_outlined,
                            size: 18,
                            color:
                                theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            s.identityBackupDesc,
                            style: TextStyle(
                              fontSize: 12.8,
                              height: 1.5,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (identity.hasMnemonic)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _toggleReveal,
                          icon: Icon(
                            _revealed
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            size: 18,
                          ),
                          label: Text(
                            _revealed
                                ? s.identityHideMnemonic
                                : s.identityShowMnemonic,
                          ),
                        ),
                      )
                    else
                      // 私鑰匯入的身份沒有助記詞，備份對象就是私鑰本身。
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Icon(Icons.warning_amber_rounded,
                                size: 17, color: AppColors.warning),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                s.importPrivateKeyWarn,
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
                    if (_revealed && mnemonicWords.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 14),
                      _AutoHideNotice(secondsLeft: _hideLeft),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            for (var i = 0; i < mnemonicWords.length; i++)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Text(
                                  '${i + 1}. ${mnemonicWords[i]}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _copy(identity.mnemonic),
                          icon: const Icon(Icons.copy_all_rounded, size: 18),
                          label: Text(s.copy),
                        ),
                      ),
                    ],
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

/// 敏感內容顯示中的自動隱藏倒數提示。
class _AutoHideNotice extends StatelessWidget {
  const _AutoHideNotice({required this.secondsLeft});

  final int secondsLeft;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    if (secondsLeft <= 0) return const SizedBox.shrink();
    return Row(
      children: <Widget>[
        const Icon(Icons.timer_outlined, size: 15, color: AppColors.warning),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            s.autoHideIn('$secondsLeft'),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.warning,
            ),
          ),
        ),
      ],
    );
  }
}

/// 匯出敏感資料前的密碼驗證對話框。
///
/// 回傳輸入的密碼；取消時回傳 `null`。
class _PasswordPromptDialog extends StatefulWidget {
  const _PasswordPromptDialog({required this.title, required this.desc});

  final String title;
  final String desc;

  @override
  State<_PasswordPromptDialog> createState() => _PasswordPromptDialogState();
}

class _PasswordPromptDialogState extends State<_PasswordPromptDialog> {
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
          PasswordInput(
            controller: _controller,
            autofocus: true,
            label: s.passwordLabel,
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

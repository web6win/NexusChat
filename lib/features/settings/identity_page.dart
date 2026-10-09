import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/crypto/did.dart';
import '../../shared/auth.dart';
import '../../shared/feedback.dart';
import '../../shared/layout.dart';
import '../../shared/widgets.dart';
import '../../state/controllers.dart';

/// 身份页：DID 细节与助记词备份。
///
/// 显示助记词或私钥**必须先输入密码**，且显示后会倒数自动隐藏 ——
/// 避免有人在你离开座位时直接打开这个页面抄走助记词。
class IdentityPage extends ConsumerStatefulWidget {
  const IdentityPage({super.key});

  @override
  ConsumerState<IdentityPage> createState() => _IdentityPageState();
}

class _IdentityPageState extends ConsumerState<IdentityPage>
    with WidgetsBindingObserver {
  bool _revealed = false;
  Timer? _hideTimer;
  int _hideLeft = 0;

  /// 复制敏感资料后负责清空剪贴簿的计时器。
  ///
  /// 刻意**不在 dispose 时取消**：即使使用者立刻离开页面，留在剪贴簿里的
  /// 助记词仍要清掉，那才是这个机制的用意。
  Timer? _clipboardTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    super.dispose();
  }

  /// 进入背景时立刻收起敏感内容。
  ///
  /// 系统会替背景中的 App 产生缩图（工作切换器／多工画面），助记词若还
  /// 显示在画面上，等于被写进磁碟、也可能出现在萤幕录影里。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused &&
        state != AppLifecycleState.detached) {
      return;
    }
    if (!_revealed) return;
    _hideTimer?.cancel();
    setState(() {
      _revealed = false;
      _hideLeft = 0;
    });
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    showAppSnack(context, context.s.copied);
  }

  /// 复制**敏感资料**（助记词 / 私钥）并排定自动清空剪贴簿。
  ///
  /// 剪贴簿可能被云端同步（跨装置贴上）或被剪贴簿管理器长期留存，
  /// 助记词一旦留在里面，风险等同于明文外泄。这里在逾时后清空，且只清
  /// 「内容仍然是刚才那份」的情况，避免把使用者新复制的东西一并清掉。
  Future<void> _copySecret(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    showAppSnack(context, context.s.copied);
    _clipboardTimer?.cancel();
    _clipboardTimer = Timer(const Duration(seconds: 60), () async {
      final current = await Clipboard.getData(Clipboard.kTextPlain);
      if (current?.text == value) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });
  }

  /// 切换敏感内容的显示状态。
  ///
  /// 由隐藏转为显示时要求重新输入密码；由显示转为隐藏则直接关闭。
  Future<void> _toggleReveal() async {
    if (_revealed) {
      _hideTimer?.cancel();
      setState(() {
        _revealed = false;
        _hideLeft = 0;
      });
      return;
    }

    final ok = await authorizeWithPassword(
      context,
      ref,
      title: context.s.exportVerifyTitle,
      desc: context.s.exportVerifyDesc,
    );
    if (!ok || !mounted) return;
    _showSecrets();
  }

  /// 显示敏感内容并启动自动隐藏倒数。
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
              // ------------------------------------------------------ 金钥
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
                    // 私钥汇入的身份可直接复制私钥做备份（助记词身份则靠助记词）。
                    if (!identity.hasMnemonic)
                      SettingsTile(
                        icon: Icons.key_rounded,
                        title: s.importPrivateKeyLabel,
                        subtitle: _revealed
                            ? identity.ethPrivateHex
                            : '${identity.ethPrivateHex.substring(0, 12)}'
                                '${'•' * 16}',
                        onTap: () => _revealed
                            ? _copySecret(identity.ethPrivateHex)
                            : _toggleReveal(),
                      ),
                  ],
                ),
              ),
              // ------------------------------------------------------ 备份
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
                      // 私钥汇入的身份没有助记词，备份对象就是私钥本身。
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
                    // 有密码短语时一定要跟著备份：少了它，助记词会还原成
                    // 另一个身份，而且完全不会有任何错误提示。
                    if (_revealed && identity.hasPassphrase) ...<Widget>[
                      const SizedBox(height: 14),
                      Text(
                        s.identityPassphrase,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.55),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: SelectableText(
                          identity.passphrase,
                          style: const TextStyle(
                            fontSize: 13,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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
                          onPressed: () => _copySecret(identity.mnemonic),
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

/// 敏感内容显示中的自动隐藏倒数提示。
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

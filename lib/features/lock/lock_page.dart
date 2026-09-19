import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/crypto/did.dart';
import '../../shared/feedback.dart';
import '../../state/controllers.dart';
import '../security/password_fields.dart';

/// 鎖屏頁：輸入密碼才會把助記詞 / 私鑰載入記憶體。
///
/// 連續失敗會進入遞增的冷卻期，讓離線暴力嘗試的成本隨次數上升
/// （真正的防線仍是 PBKDF2 迭代與密碼強度，這裡只是補一層速率限制）。
class LockPage extends ConsumerStatefulWidget {
  const LockPage({super.key});

  @override
  ConsumerState<LockPage> createState() => _LockPageState();
}

class _LockPageState extends ConsumerState<LockPage> {
  final TextEditingController _controller = TextEditingController();
  Timer? _cooldownTimer;

  bool _busy = false;
  String? _error;
  int _failures = 0;
  int _cooldownLeft = 0;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// 失敗後的冷卻秒數：2、4、8、16、30（上限）。
  void _startCooldown() {
    final seconds = switch (_failures) {
      <= 1 => 0,
      2 => 2,
      3 => 4,
      4 => 8,
      5 => 16,
      _ => 30,
    };
    if (seconds == 0) return;
    setState(() => _cooldownLeft = seconds);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _cooldownLeft--);
      if (_cooldownLeft <= 0) timer.cancel();
    });
  }

  Future<void> _unlock() async {
    if (_busy || _cooldownLeft > 0) return;
    final password = _controller.text;
    if (password.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final code = await ref.read(sessionProvider.notifier).unlock(password);
    if (!mounted) return;

    if (code == null) {
      // 成功：清掉輸入框內容，路由會自動切走。
      _controller.clear();
      setState(() => _busy = false);
      sessionVersion.value++;
      return;
    }

    _failures++;
    setState(() {
      _busy = false;
      _error = context.s.unlockWrong;
    });
    _startCooldown();
  }

  Future<void> _forgotPassword() async {
    final s = context.s;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.unlockForgotTitle),
        content: Text(s.unlockForgotDesc),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(s.cancel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final address = ref.read(coreProvider).accountAddress;
    final shortAddress = address.isEmpty
        ? ''
        : Did.shortDid(Did.isEthrDid(address) ? address : Did.fromAddress(address));

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
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    s.unlockTitle,
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.unlockDesc,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                    ),
                  ),
                  if (shortAddress.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.account_circle_outlined,
                            size: 17,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.55),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              shortAddress,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  PasswordInput(
                    controller: _controller,
                    autofocus: true,
                    enabled: !_busy && _cooldownLeft == 0,
                    label: s.passwordLabel,
                    errorText: _error,
                    onSubmitted: (_) => _unlock(),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: (_busy || _cooldownLeft > 0) ? null : _unlock,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _cooldownLeft > 0
                                ? s.unlockCooldown('$_cooldownLeft')
                                : s.unlockAction,
                          ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: _forgotPassword,
                      child: Text(s.unlockForgot),
                    ),
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

/// 提示：本機已存在身份但保險庫結構異常（無密文可用）。
///
/// 這是防禦性分支 —— 正常流程不應出現，出現時唯一的出路是重新建立身份。
class VaultUnavailablePage extends ConsumerWidget {
  const VaultUnavailablePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.s;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.report_gmailerrorred_rounded,
                    size: 44,
                    color: AppColors.danger,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    s.vaultUnavailableTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    s.vaultUnavailableDesc,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: () async {
                      await ref.read(sessionProvider.notifier).wipeIdentity();
                      if (context.mounted) {
                        showAppSnack(context, context.s.wiped);
                      }
                    },
                    child: Text(s.wipe),
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

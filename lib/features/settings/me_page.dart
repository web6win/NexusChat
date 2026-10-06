import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../data/crypto/did.dart';
import '../../data/models/chain.dart';
import '../../shared/feedback.dart';
import '../../shared/layout.dart';
import '../../shared/widgets.dart';
import '../../state/controllers.dart';
import 'settings_page.dart';

/// 「我」页面：把原本独立的「设定」入口收进个人页，
/// 顶部展示身份资料（头像 / 暱称 / DID / 地址，可复制），
/// 下方则是分组后的设定目录。
class MePage extends ConsumerWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.s;
    final settings = ref.watch(settingsProvider);
    final chain = settings.chain;
    final identity = ref.watch(sessionProvider).identity;
    final did = identity?.did ?? '';
    final address = identity?.address ?? '';
    // 依链显示对应地址：EVM 系为 EIP-55 的 0x，TRON 为 T 开头 Base58Check。
    final displayAddress = chain == ChainType.tron
        ? (identity?.tronAddress ?? '')
        : Did.eip55(address);
    final nickname = settings.nickname;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ContentColumn(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: <Widget>[
              PageHeader(
                title: s.navMe,
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
              ),
              _MeHeader(
                did: did,
                displayAddress: displayAddress,
                nickname: nickname,
                onCopyDid: () => _copy(context, did),
                onCopyAddress: () => _copy(context, displayAddress),
              ),
              const SizedBox(height: 18),
              const SettingsDirectory(),
            ],
          ),
        ),
      ),
    );
  }

  void _copy(BuildContext context, String value) {
    if (value.isEmpty) return;
    Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) showAppSnack(context, context.s.copied);
  }
}

/// 由字串杂凑推导一个稳定的颜色，让头像随身份而变但不刺眼。
Color _colorFor(String input) {
  final hue = (input.hashCode.abs() % 360).toDouble();
  return HSLColor.fromAHSL(1, hue, 0.6, 0.52).toColor();
}

/// 个人资料卡：头像 + 暱称 / DID / 地址，后两者可点击复制。
class _MeHeader extends StatelessWidget {
  const _MeHeader({
    required this.did,
    required this.displayAddress,
    required this.nickname,
    required this.onCopyDid,
    required this.onCopyAddress,
  });

  final String did;
  final String displayAddress;
  final String nickname;
  final VoidCallback onCopyDid;
  final VoidCallback onCopyAddress;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final title = nickname.isNotEmpty ? nickname : s.identityTitle;
    final didShort = did.isNotEmpty ? Did.shortDid(did) : '—';
    final addressShort = displayAddress.isNotEmpty
        ? Did.shortAddress(displayAddress, head: 8, tail: 8)
        : '—';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          AppAvatar(
            name: did.isNotEmpty ? did : '?',
            color: _colorFor(did),
            size: 64,
            ring: true,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                _CopyRow(label: didShort, onTap: onCopyDid),
                const SizedBox(height: 4),
                _CopyRow(label: addressShort, onTap: onCopyAddress),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 一行可复制的文字（等宽字 + 复制图示），用于展示 DID / 地址。
class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.copy_rounded,
              size: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ],
        ),
      ),
    );
  }
}

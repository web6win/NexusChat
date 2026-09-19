import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/chain.dart';
import '../../shared/feedback.dart';
import '../../state/controllers.dart';

/// 收款面板：顯示目前所選鏈的地址 + QR Code，並支援複製。
///
/// 地址即帳戶地址本身（EVM 為 EIP-55 的 0x…，TRON 為 Base58Check 的 T…），
/// 因此 QR 內容就是純地址字串，任何錢包都能掃。
class ReceiveSheet extends ConsumerWidget {
  const ReceiveSheet({required this.address, super.key});

  final String address;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.s;
    final theme = Theme.of(context);
    final chain = ref.watch(settingsProvider).chain;
    final config = ChainConfig.of(chain);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(_icon(chain), size: 19, color: AppColors.brand),
                    const SizedBox(width: 8),
                    Text(
                      s.walletReceive,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: QrImageView(
                    data: address,
                    version: QrVersions.auto,
                    size: 210,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(color: Color(0xFF101320)),
                    dataModuleStyle: const QrDataModuleStyle(
                      color: Color(0xFF101320),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '${config.symbol} · ${_chainLabel(s, chain)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  address,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontFamily: 'monospace',
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: address));
                          if (context.mounted) {
                            showAppSnack(context, s.copied);
                          }
                        },
                        icon: const Icon(Icons.copy_rounded),
                        label: Text(s.copy),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.check_rounded),
                        label: Text(s.done),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  s.walletReceiveDesc,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _icon(ChainType c) => switch (c) {
        ChainType.ethereum => Icons.diamond_outlined,
        ChainType.tron => Icons.offline_bolt_rounded,
        ChainType.besu => Icons.hub_outlined,
      };

  static String _chainLabel(Strings s, ChainType c) => switch (c) {
        ChainType.ethereum => s.chainEthereum,
        ChainType.tron => s.chainTron,
        ChainType.besu => s.chainBesu,
      };
}

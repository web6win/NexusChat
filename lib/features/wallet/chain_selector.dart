import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/chain.dart';

/// 區塊鏈切換器：點擊彈出清單選擇鏈。
///
/// 錢包頁與轉帳頁共用同一份 [ChainType] 狀態（存在設定裡），因此任何一處
/// 切換，另一處與 [walletSendProvider] 看到的鏈都會一致 —— 轉帳的方向
/// 絕不能和畫面上顯示的鏈不一致。
class ChainSelector extends StatelessWidget {
  const ChainSelector({
    required this.chain,
    required this.onChanged,
    this.dense = false,
    super.key,
  });

  final ChainType chain;
  final ValueChanged<ChainType> onChanged;

  /// 用於空間較小的位置（例如轉帳頁的網路卡）時稍微壓低高度。
  final bool dense;

  static IconData iconOf(ChainType c) => switch (c) {
        ChainType.ethereum => Icons.diamond_outlined,
        ChainType.base => Icons.square_outlined,
        ChainType.arbitrum => Icons.hexagon_outlined,
        ChainType.bsc => Icons.monetization_on_outlined,
        ChainType.tron => Icons.offline_bolt_rounded,
        ChainType.besu => Icons.hub_outlined,
      };

  static String labelOf(Strings s, ChainType c) => switch (c) {
        ChainType.ethereum => s.chainEthereum,
        ChainType.base => s.chainBase,
        ChainType.arbitrum => s.chainArbitrum,
        ChainType.bsc => s.chainBsc,
        ChainType.tron => s.chainTron,
        ChainType.besu => s.chainBesu,
      };

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<ChainType>(
      onSelected: onChanged,
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.under,
      color: scheme.surface,
      elevation: 8,
      tooltip: s.walletSwitchNetwork,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.18)),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 13,
          vertical: dense ? 7 : 9,
        ),
        decoration: BoxDecoration(
          color: AppColors.brand.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: AppColors.brand.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(iconOf(chain), size: 16, color: AppColors.brand),
            const SizedBox(width: 7),
            Text(
              labelOf(s, chain),
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: scheme.onSurface.withValues(alpha: 0.55),
            ),
          ],
        ),
      ),
      itemBuilder: (context) => <PopupMenuEntry<ChainType>>[
        PopupMenuItem<ChainType>(
          enabled: false,
          height: 32,
          child: Text(
            s.chainSelect,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: scheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ),
        for (final c in ChainType.values)
          PopupMenuItem<ChainType>(
            value: c,
            child: Row(
              children: <Widget>[
                Icon(
                  iconOf(c),
                  size: 19,
                  color: c == chain ? AppColors.brand : scheme.onSurface,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    labelOf(s, c),
                    style: TextStyle(
                      fontWeight:
                          c == chain ? FontWeight.w700 : FontWeight.w500,
                      color: c == chain ? AppColors.brand : null,
                    ),
                  ),
                ),
                if (c == chain)
                  const Icon(Icons.check_rounded,
                      size: 18, color: AppColors.brand),
              ],
            ),
          ),
      ],
    );
  }
}

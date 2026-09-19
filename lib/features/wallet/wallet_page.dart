import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../data/crypto/did.dart';
import '../../data/models/chain.dart';
import '../../shared/feedback.dart';
import '../../shared/layout.dart';
import '../../shared/widgets.dart';
import '../../state/controllers.dart';
import 'receive_sheet.dart';
import 'send_page.dart';

/// 錢包頁：顯示目前所選鏈的帳戶資訊（餘額、ENS、chain、DID）。
///
/// 版面依「一眼看到重點」排序：鏈別 → 餘額 → 主要操作（轉帳 / 收款）
/// → 帳戶與網路細節。桌機視窗很寬時內容會收在 [AppBreakpoints.content]
/// 之內並置中，避免卡片橫向鋪滿整個畫面。
class WalletPage extends ConsumerWidget {
  const WalletPage({super.key});

  Future<void> _copy(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    showAppSnack(context, context.s.copied);
  }

  /// 用外部瀏覽器開啟區塊瀏覽器。
  Future<void> _openExplorer(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// 彈出收款面板（地址 + QR Code）。
  Future<void> _showReceive(BuildContext context, String address) {
    if (address.isEmpty) return Future<void>.value();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => ReceiveSheet(address: address),
    );
  }

  static String chainName(Strings s, ChainType c) => switch (c) {
        ChainType.ethereum => s.chainEthereum,
        ChainType.tron => s.chainTron,
        ChainType.besu => s.chainBesu,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.s;
    final identity = ref.watch(sessionProvider).identity;
    final settings = ref.watch(settingsProvider);
    final info = ref.watch(walletInfoProvider);
    final chain = settings.chain;
    final config = ChainConfig.of(chain);
    final address = identity?.address ?? '';
    final did = identity?.did ?? '';
    // 依鏈顯示對應地址：EVM 系（以太坊 / Besu 聯盟鏈）為 EIP-55 的 0x，
    // TRON 為 T 開頭 Base58Check。
    final displayAddress = chain == ChainType.tron
        ? (identity?.tronAddress ?? '')
        : Did.eip55(address);

    final busy = info.isLoading;
    // 查不到餘額且不在載入中：RPC 未設定或連線失敗，兩者提示文字不同。
    final unavailable = info.value?.balanceNative == null && !busy;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(walletInfoProvider),
          child: ContentColumn(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
              children: <Widget>[
                PageHeader(
                  title: s.walletTitle,
                  padding: const EdgeInsets.fromLTRB(4, 10, 0, 16),
                  actions: <Widget>[
                    _ChainSelector(
                      chain: chain,
                      onChanged: (c) {
                        ref.read(settingsProvider.notifier).setChain(c);
                        ref.invalidate(walletInfoProvider);
                      },
                    ),
                    IconButton(
                      tooltip: s.walletRefresh,
                      onPressed: () => ref.invalidate(walletInfoProvider),
                      icon: const Icon(Icons.refresh_rounded, size: 21),
                    ),
                  ],
                ),
                // -------------------------------------------------- 餘額卡片
                _BalanceCard(
                  // 一律使用介面語言的鏈名，與上方標題列的鏈別標籤一致；
                  // 舊版此處直接用 settings.chainName（永遠是英文的
                  // "Ethereum Mainnet"），同一畫面會出現兩種名稱。
                  chainLabel: chainName(s, chain),
                  chainIcon: _ChainSelector.iconOf(chain),
                  chainId: info.value?.chainId,
                  balanceText: Formatters.amount(
                    info.value?.balanceNative,
                    config.displayDecimals,
                  ),
                  symbol: config.symbol,
                  address: displayAddress,
                  busy: busy,
                  onCopyAddress: () => _copy(context, displayAddress),
                ),
                const SizedBox(height: 14),
                // ------------------------------------------------ 主要操作
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SendPage(chain: chain),
                          ),
                        ),
                        icon: const Icon(Icons.arrow_upward_rounded, size: 19),
                        label: Text(s.walletSend),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showReceive(context, displayAddress),
                        icon: const Icon(Icons.qr_code_2_rounded, size: 19),
                        label: Text(s.walletReceive),
                      ),
                    ),
                  ],
                ),
                if (unavailable) ...<Widget>[
                  const SizedBox(height: 14),
                  _NoticeBanner(
                    text: settings.rpcFor(chain).isEmpty
                        ? s.walletNoRpc
                        : s.errorNetwork,
                  ),
                ],
                // -------------------------------------------------- 帳戶資訊
                SectionCard(
                  title: s.identityTitle,
                  child: Column(
                    children: <Widget>[
                      SettingsTile(
                        icon: Icons.fingerprint_rounded,
                        title: s.walletDid,
                        subtitle: Did.shortDid(did),
                        onTap: () => _copy(context, did),
                      ),
                      SettingsTile(
                        icon: Icons.badge_outlined,
                        title: s.walletAddress,
                        subtitle: displayAddress,
                        onTap: () => _copy(context, displayAddress),
                      ),
                      if (config.supportsEns)
                        SettingsTile(
                          icon: Icons.language_rounded,
                          title: s.walletEns,
                          subtitle: info.value?.domainName ?? '--',
                          onTap: null,
                        ),
                    ],
                  ),
                ),
                // ------------------------------------------------------ 網路
                SectionCard(
                  title: s.settingsNetwork,
                  child: Column(
                    children: <Widget>[
                      SettingsTile(
                        icon: Icons.cable_rounded,
                        title: s.walletRpcUrl,
                        subtitle: settings.rpcFor(chain),
                        onTap: null,
                      ),
                      if (config.explorerHost.isNotEmpty)
                        SettingsTile(
                          icon: Icons.open_in_new_rounded,
                          title: s.walletExplorer,
                          subtitle: config.explorerHost,
                          onTap: () => _openExplorer(config.explorerUrl),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 餘額卡片：鏈別徽章 + chainId + 餘額 + 可複製地址。
///
/// 用外層陰影做出「浮在頁面上」的層次；卡片內部疊了兩圈半透明圓形，
/// 讓純漸層背景多一點深度，不至於太平。
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.chainLabel,
    required this.chainIcon,
    required this.chainId,
    required this.balanceText,
    required this.symbol,
    required this.address,
    required this.busy,
    required this.onCopyAddress,
  });

  final String chainLabel;
  final IconData chainIcon;
  final int? chainId;
  final String balanceText;
  final String symbol;
  final String address;
  final bool busy;
  final VoidCallback onCopyAddress;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.34),
            blurRadius: 30,
            spreadRadius: -8,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: <Widget>[
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Color(0xFF5B4BE0), Color(0xFF8E7BFF)],
                  ),
                ),
              ),
            ),
            // 裝飾用光暈，純視覺、不影響版面。
            const Positioned(right: -70, top: -80, child: _Glow(size: 200)),
            const Positioned(right: 40, bottom: -90, child: _Glow(size: 150)),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      _GlassChip(icon: chainIcon, label: chainLabel),
                      const Spacer(),
                      if (chainId != null)
                        Text(
                          '${s.walletChainId} $chainId',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    s.walletBalance,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          balanceText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                Colors.white.withValues(alpha: busy ? 0.55 : 1),
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          symbol,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (busy) ...<Widget>[
                        const SizedBox(width: 10),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 9),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  _AddressRow(address: address, onTap: onCopyAddress),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 卡片上的半透明圓形裝飾。
class _Glow extends StatelessWidget {
  const _Glow({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.07),
      ),
    );
  }
}

/// 漸層卡片上的玻璃質感標籤。
class _GlassChip extends StatelessWidget {
  const _GlassChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 卡片上的地址列：點擊複製。
class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.address, required this.onTap});

  final String address;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: Text(
                address,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.copy_rounded,
              size: 14,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ],
        ),
      ),
    );
  }
}

/// 提示橫幅：用來顯示「尚未設定 RPC」這類不阻斷操作的狀況。
class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.info_outline_rounded,
              size: 17, color: AppColors.warning),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 錢包左上角的區塊鏈切換器：點擊彈出清單選擇鏈。
///
/// 與設定頁的區段控制共用同一份 [ChainType] 狀態；切換後由呼叫方
/// invalidate [walletInfoProvider] 以重新拉取餘額。
class _ChainSelector extends StatelessWidget {
  const _ChainSelector({
    required this.chain,
    required this.onChanged,
  });

  final ChainType chain;
  final ValueChanged<ChainType> onChanged;

  static IconData iconOf(ChainType c) => switch (c) {
        ChainType.ethereum => Icons.diamond_outlined,
        ChainType.tron => Icons.offline_bolt_rounded,
        ChainType.besu => Icons.hub_outlined,
      };

  static String _label(Strings s, ChainType c) => switch (c) {
        ChainType.ethereum => s.chainEthereum,
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.18)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
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
              _label(s, chain),
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
                    _label(s, c),
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

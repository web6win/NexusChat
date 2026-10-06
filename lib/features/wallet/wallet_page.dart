import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import 'chain_selector.dart';
import 'receive_sheet.dart';
import 'token_panel.dart';

/// 钱包页：显示目前所选链的帐户资讯（余额、ENS、chain、DID）。
///
/// 版面依「一眼看到重点」排序：链别 → 余额 → 主要操作（转帐 / 收款）
/// → 帐户与网路细节。桌机视窗很宽时内容会收在 [AppBreakpoints.content]
/// 之内并置中，避免卡片横向铺满整个画面。
class WalletPage extends ConsumerWidget {
  const WalletPage({super.key});

  Future<void> _copy(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    showAppSnack(context, context.s.copied);
  }

  /// 用外部浏览器开启区块浏览器。
  Future<void> _openExplorer(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// 弹出收款面板（地址 + QR Code）。
  Future<void> _showReceive(BuildContext context, String address) {
    if (address.isEmpty) return Future<void>.value();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => ReceiveSheet(address: address),
    );
  }

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
    // 依链显示对应地址：EVM 系（以太坊 / Besu 联盟链）为 EIP-55 的 0x，
    // TRON 为 T 开头 Base58Check。
    final displayAddress = chain == ChainType.tron
        ? (identity?.tronAddress ?? '')
        : Did.eip55(address);
    // 卡片与列表只展示「前 8 位…后 8 位」，复制时仍用完整地址。
    final displayAddressShort = Did.shortAddress(
      displayAddress,
      head: 8,
      tail: 8,
    );

    final busy = info.isLoading;
    // 查不到余额且不在载入中：RPC 未设定或连线失败，两者提示文字不同。
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
                    ChainSelector(
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
                // -------------------------------------------------- 余额卡片
                _BalanceCard(
                  // 一律使用介面语言的链名，与上方标题列的链别标签一致。
                  chainLabel: ChainSelector.labelOf(s, chain),
                  chainIcon: ChainSelector.iconOf(chain),
                  chainId: info.value?.chainId,
                  balanceText: Formatters.amount(
                    info.value?.balanceNative,
                    config.displayDecimals,
                  ),
                  symbol: config.symbol,
                  address: displayAddressShort,
                  busy: busy,
                  onCopyAddress: () => _copy(context, displayAddress),
                ),
                const SizedBox(height: 14),
                // ------------------------------------------------ 主要操作
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () =>
                            context.push('/send?chain=${chain.id}'),
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
                // ------------------------------------------------ 常用通证面板
                TokenPanel(chain: chain),
                // -------------------------------------------------- 帐户资讯
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
                        subtitle: displayAddressShort,
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
                // ------------------------------------------------------ 网路
                SectionCard(
                  title: s.settingsNetwork,
                  child: Column(
                    children: <Widget>[
                      SettingsTile(
                        icon: Icons.toll_rounded,
                        title: s.walletNativeToken,
                        // 代币全名 + 代号，例如 Contribution (CNT)。
                        subtitle: '${config.name} (${config.symbol})',
                        onTap: null,
                      ),
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

/// 余额卡片：链别徽章 + chainId + 余额 + 可复制地址。
///
/// 用外层阴影做出「浮在页面上」的层次；卡片内部叠了两圈半透明圆形，
/// 让纯渐层背景多一点深度，不至于太平。
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
            // 装饰用光晕，纯视觉、不影响版面。
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

/// 卡片上的半透明圆形装饰。
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

/// 渐层卡片上的玻璃质感标签。
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

/// 卡片上的地址列：点击复制。
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

/// 提示横幅：用来显示「尚未设定 RPC」这类不阻断操作的状况。
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



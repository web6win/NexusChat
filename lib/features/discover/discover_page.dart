import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/layout.dart';
import '../../shared/widgets.dart';

/// 发现页：放置不属于「聊天 / 联络人 / 钱包 / 设定」的独立工具。
///
/// 目前有两个工具：
/// - 「扫一扫」：以相机读取 QR Code，扫到网址会开启应用内浏览器，
///   扫到 DID / 地址 / ENS 则可一键加入联络人。
/// - 「浏览器」：内嵌 WebView 的浏览器，可手动输入网址。
class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ContentColumn(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              PageHeader(
                title: s.discoverTitle,
                subtitle: s.discoverSubtitle,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                  children: <Widget>[
                    SectionCard(
                      title: s.discoverTools,
                      child: Column(
                        children: <Widget>[
                          _ScanTile(onTap: () => context.push('/scan')),
                          const Divider(height: 1),
                          // 不带网址进入：浏览器先显示起始页，由使用者输入网址。
                          _BrowserTile(onTap: () => context.push('/webview')),
                        ],
                      ),
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

/// 「浏览器」入口：开启内嵌 WebView 的浏览器，可手动输入网址。
class _BrowserTile extends StatelessWidget {
  const _BrowserTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.all(Radius.circular(14)),
              ),
              child: Icon(
                Icons.language_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    s.browserTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    s.browserDesc,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

/// 「扫一扫」入口：用品牌渐层色块当作视觉重点，让它是这一页最显眼的操作。
class _ScanTile extends StatelessWidget {
  const _ScanTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    s.discoverScan,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    s.discoverScanDesc,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

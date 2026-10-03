import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../shared/layout.dart';
import '../../shared/widgets.dart';

/// 設定首頁：以分組目錄的方式列出各設定分頁，點擊進入對應的子頁面，
/// 避免把所有選項都堆在同一個頁面。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    // 每個分類：標題、說明（更具體的中文副標）、圖示、目標路由、是否危險項。
    final categories = <_Category>[
      _Category(
        title: s.settingsAppearance,
        subtitle: s.settingsSubAppearance,
        icon: Icons.palette_rounded,
        route: '/settings/appearance',
      ),
      _Category(
        title: s.securitySection,
        subtitle: s.settingsSubSecurity,
        icon: Icons.shield_outlined,
        route: '/settings/security',
      ),
      _Category(
        title: s.settingsNetwork,
        subtitle: s.settingsSubNetwork,
        icon: Icons.hub_rounded,
        route: '/settings/network',
      ),
      _Category(
        title: s.walletChain,
        subtitle: s.settingsSubBlockchain,
        icon: Icons.account_balance_wallet_outlined,
        route: '/settings/blockchain',
      ),
      _Category(
        title: s.identityTitle,
        subtitle: s.settingsSubIdentity,
        icon: Icons.fingerprint_rounded,
        route: '/settings/identity',
      ),
      _Category(
        title: s.importPrivateKeyTitle,
        subtitle: s.settingsSubImportKey,
        icon: Icons.key_rounded,
        route: '/settings/import-key',
      ),
      _Category(
        title: s.settingsAbout,
        subtitle: s.settingsSubAbout,
        icon: Icons.info_outline_rounded,
        route: '/settings/about',
      ),
      _Category(
        title: s.settingsDelete,
        subtitle: s.settingsSubDanger,
        icon: Icons.warning_amber_rounded,
        route: '/settings/danger',
        danger: true,
      ),
    ];

    // 依主題將分類歸到四個群組。
    final groups = <_Group>[
      _Group(s.settingsGroupGeneral, <_Category>[
        categories[0], // 外觀與語言
        categories[6], // 關於
      ]),
      _Group(s.settingsGroupAccount, <_Category>[
        categories[4], // 身份
        categories[5], // 匯入私鑰
        categories[1], // 安全
      ]),
      _Group(s.settingsGroupConnection, <_Category>[
        categories[2], // 網路
        categories[3], // 區塊鏈
      ]),
      _Group(s.settingsGroupDanger, <_Category>[
        categories[7], // 危險操作
      ]),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ContentColumn(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: <Widget>[
              PageHeader(
                title: s.settingsTitle,
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
              ),
              for (final group in groups) ...<Widget>[
                _GroupHeader(title: group.title),
                for (final c in group.items) ...<Widget>[
                  SectionCard(
                    child: SettingsTile(
                      icon: c.icon,
                      title: c.title,
                      subtitle: c.subtitle,
                      danger: c.danger,
                      onTap: () => context.push(c.route),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 設定首頁的一個分類入口。
class _Category {
  const _Category({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    this.danger = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final bool danger;
}

/// 設定首頁的一個分組（例如「通用」「連線」「帳號」「危險區」）。
class _Group {
  const _Group(this.title, this.items);

  final String title;
  final List<_Category> items;
}

/// 分組標題：小號、半透明、字距略寬，作為目錄的分段提示。
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 14, 6, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

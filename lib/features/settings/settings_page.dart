import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../shared/widgets.dart';

/// 设定目录：依群组列出各设定分类，点击进入对应子页面。
///
/// 设计成无外框的元件，通常嵌在「我」页面中，作为帐号与偏好的集中入口；
/// 需要独立成页时，由呼叫方自行包上 [Scaffold] / [ContentColumn]。
class SettingsDirectory extends StatelessWidget {
  const SettingsDirectory({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    // 每个分类：标题、说明（更具体的中文副标）、图示、目标路由、是否危险项。
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

    // 依主题将分类归到四个群组。
    final groups = <_Group>[
      _Group(s.settingsGroupGeneral, <_Category>[
        categories[0], // 外观与语言
        categories[6], // 关于
      ]),
      _Group(s.settingsGroupAccount, <_Category>[
        categories[4], // 身份
        categories[5], // 汇入私钥
        categories[1], // 安全
      ]),
      _Group(s.settingsGroupConnection, <_Category>[
        categories[2], // 网路
        categories[3], // 区块链
      ]),
      _Group(s.settingsGroupDanger, <_Category>[
        categories[7], // 危险操作
      ]),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final group in groups) ...<Widget>[
          _GroupHeader(title: group.title),
          for (final c in group.items)
            SectionCard(
              child: SettingsTile(
                icon: c.icon,
                title: c.title,
                subtitle: c.subtitle,
                danger: c.danger,
                onTap: () => context.push(c.route),
              ),
            ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// 设定目录的一个分类入口。
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

/// 设定目录的一个分组（例如「通用」「连线」「帐号」「危险区」）。
class _Group {
  const _Group(this.title, this.items);

  final String title;
  final List<_Category> items;
}

/// 分组标题：小号、半透明、字距略宽，作为目录的分段提示。
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/contacts/contacts_page.dart';
import '../features/discover/discover_page.dart';
import '../features/discover/scan_page.dart';
import '../features/discover/webview_page.dart';
import '../features/lock/lock_page.dart';
import '../features/onboarding/create_identity_page.dart';
import '../features/onboarding/restore_page.dart';
import '../features/onboarding/welcome_page.dart';
import '../features/chats/chats_page.dart';
import '../features/chats/group_create_page.dart';
import '../features/chats/group_info_page.dart';
import '../features/security/migrate_page.dart';
import '../features/settings/about_settings_page.dart';
import '../features/settings/appearance_settings_page.dart';
import '../features/settings/blockchain_settings_page.dart';
import '../features/settings/danger_settings_page.dart';
import '../features/settings/identity_import_page.dart';
import '../features/settings/identity_page.dart';
import '../features/settings/network_settings_page.dart';
import '../features/settings/security_settings_page.dart';
import '../features/settings/me_page.dart';
import '../features/wallet/send_page.dart';
import '../features/wallet/wallet_page.dart';
import '../data/models/chain.dart';
import '../state/controllers.dart';
import 'shell.dart';

/// 路由设定。桌面与行动共用同一组路由，由壳层决定排版。
///
/// 导向规则（依序判断）：
/// 1. 存在旧版明文身份 → `/migrate`（强制设定密码，完成加密迁移）。
/// 2. 已有身份但未解锁 → `/lock`（记忆体中没有任何秘密）。
/// 3. 已解锁 → 进入主壳层；此时不允许停留在引导 / 锁屏 / 迁移页。
/// 4. 完全没有身份 → `/welcome`。
final routerProvider = Provider<GoRouter>((ref) {
  final core = ref.read(coreProvider);

  return GoRouter(
    initialLocation: '/chats',
    refreshListenable: sessionVersion,
    redirect: (BuildContext context, GoRouterState state) {
      final location = state.matchedLocation;
      final isOnboarding = location == '/welcome' ||
          location == '/restore' ||
          location == '/create';
      final isLock = location == '/lock';
      final isMigrate = location == '/migrate';
      final isRecover = location == '/recover';

      // 1) 旧版明文身份：先完成加密迁移，否则不给进。
      if (core.needsMigration) {
        return isMigrate ? null : '/migrate';
      }

      // 2) 有身份但保险库不可用（结构毁损）：只能走修复页。
      if (core.hasIdentity && !core.vaultUsable) {
        return isRecover ? null : '/recover';
      }

      // 3) 已锁定：只能待在锁屏。
      if (core.isLocked) {
        return isLock ? null : '/lock';
      }

      // 4) 已解锁。
      if (core.identity != null) {
        if (isOnboarding || isLock || isMigrate || isRecover) return '/chats';
        return null;
      }

      // 5) 全新使用者：只能停在引导页与「扫码」页。
      //
      //    `/scan` 必须放行 —— 它是导入流程的一环（从 /restore 扫助记词 /
      //    私钥）。少了这一条，全新使用者点扫码会被踢回 /welcome，
      //    看起来就像「点了扫码却回到初始页」。
      return (isOnboarding || location == '/scan') ? null : '/welcome';
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/welcome',
        builder: (BuildContext context, GoRouterState state) =>
            const WelcomePage(),
      ),
      GoRoute(
        path: '/create',
        builder: (BuildContext context, GoRouterState state) =>
            const CreateIdentityPage(),
      ),
      GoRoute(
        path: '/restore',
        builder: (BuildContext context, GoRouterState state) => RestorePage(
          // 由扫码带入的助记词 / 私钥（走 extra，不出现在网址上）。
          initialValue: state.extra is String ? state.extra! as String : null,
        ),
      ),
      GoRoute(
        path: '/lock',
        builder: (BuildContext context, GoRouterState state) =>
            const LockPage(),
      ),
      GoRoute(
        path: '/migrate',
        builder: (BuildContext context, GoRouterState state) =>
            const MigrateVaultPage(),
      ),
      GoRoute(
        path: '/recover',
        builder: (BuildContext context, GoRouterState state) =>
            const VaultUnavailablePage(),
      ),
      // 扫一扫放在根导览：全萤幕取景，不被底部导览与壳层版面干扰。
      GoRoute(
        path: '/webview',
        builder: (BuildContext context, GoRouterState state) {
          final raw = state.uri.queryParameters['url'];
          final url = raw == null || raw.isEmpty ? '' : Uri.decodeComponent(raw);
          return WebViewPage(url: url);
        },
      ),
      GoRoute(
        path: '/scan',
        builder: (BuildContext context, GoRouterState state) => ScanPage(
          // 转帐页呼叫时只挑收款地址；浏览器呼叫时只挑网址；
          // 一般扫码则走完整的结果处理。
          pickAddress: state.uri.queryParameters['pick'] == '1',
          pickUrl: state.uri.queryParameters['pickUrl'] == '1',
          pickRaw: state.uri.queryParameters['pickRaw'] == '1',
          chain: state.uri.queryParameters['chain'] == null
              ? null
              : ChainType.fromId(state.uri.queryParameters['chain']),
        ),
      ),
      // 转帐页：可由钱包页进入，也可由扫码结果直接带地址与金额进来。
      GoRoute(
        path: '/send',
        builder: (BuildContext context, GoRouterState state) => SendPage(
          chain: state.uri.queryParameters['chain'] == null
              ? null
              : ChainType.fromId(state.uri.queryParameters['chain']),
          initialAddress: state.uri.queryParameters['address'],
        ),
      ),
      // 从导览页进入的子页面：刻意放在 StatefulShellRoute **之外**，
      // 因此它们天生不带底部导览（不是条件隐藏，而是壳层根本没参与）；
      // 进入时用 push 建立返回堆叠，AppBar 会自动出现左上返回箭头，
      // 实体返回键与手势返回也都能回到上一页。
      GoRoute(
        path: '/group-create',
        builder: (BuildContext context, GoRouterState state) =>
            const GroupCreatePage(),
      ),
      GoRoute(
        path: '/group-info',
        builder: (BuildContext context, GoRouterState state) => GroupInfoPage(
          groupId: state.uri.queryParameters['group'] ?? '',
        ),
      ),
      GoRoute(
        path: '/settings/appearance',
        builder: (BuildContext context, GoRouterState state) =>
            const AppearanceSettingsPage(),
      ),
      GoRoute(
        path: '/settings/security',
        builder: (BuildContext context, GoRouterState state) =>
            const SecuritySettingsPage(),
      ),
      GoRoute(
        path: '/settings/network',
        builder: (BuildContext context, GoRouterState state) =>
            const NetworkSettingsPage(),
      ),
      GoRoute(
        path: '/settings/blockchain',
        builder: (BuildContext context, GoRouterState state) =>
            const BlockchainSettingsPage(),
      ),
      GoRoute(
        path: '/settings/identity',
        builder: (BuildContext context, GoRouterState state) =>
            const IdentityPage(),
      ),
      GoRoute(
        path: '/settings/import-key',
        builder: (BuildContext context, GoRouterState state) =>
            IdentityImportPage(
              // 由扫码带入的私钥（走 extra，不出现在网址上）。
              initialKey: state.extra is String ? state.extra! as String : null,
            ),
      ),
      GoRoute(
        path: '/settings/about',
        builder: (BuildContext context, GoRouterState state) =>
            const AboutSettingsPage(),
      ),
      GoRoute(
        path: '/settings/danger',
        builder: (BuildContext context, GoRouterState state) =>
            const DangerSettingsPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder:
            (BuildContext context, GoRouterState state, StatefulNavigationShell shell) =>
                AppShell(shell: shell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            navigatorKey: _chatsKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/chats',
                builder: (BuildContext context, GoRouterState state) =>
                    ChatsPage(
                  peerDid: state.uri.queryParameters['peer'],
                  groupId: state.uri.queryParameters['group'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _contactsKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/contacts',
                builder: (BuildContext context, GoRouterState state) =>
                    const ContactsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _walletKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/wallet',
                builder: (BuildContext context, GoRouterState state) =>
                    const WalletPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _discoverKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/discover',
                builder: (BuildContext context, GoRouterState state) =>
                    const DiscoverPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _meKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/settings',
                builder: (BuildContext context, GoRouterState state) =>
                    const MePage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

final GlobalKey<NavigatorState> _rootKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _chatsKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _contactsKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _walletKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _discoverKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _meKey = GlobalKey<NavigatorState>();

/// 让外部（例如身份删除）能跳回引导页。
GlobalKey<NavigatorState> get rootNavigatorKey => _rootKey;

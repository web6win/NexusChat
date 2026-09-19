import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/contacts/contacts_page.dart';
import '../features/lock/lock_page.dart';
import '../features/onboarding/create_identity_page.dart';
import '../features/onboarding/restore_page.dart';
import '../features/onboarding/welcome_page.dart';
import '../features/chats/chats_page.dart';
import '../features/security/migrate_page.dart';
import '../features/settings/identity_page.dart';
import '../features/settings/settings_page.dart';
import '../features/wallet/wallet_page.dart';
import '../state/controllers.dart';
import 'shell.dart';

/// 路由設定。桌面與行動共用同一組路由，由殼層決定排版。
///
/// 導向規則（依序判斷）：
/// 1. 存在舊版明文身份 → `/migrate`（強制設定密碼，完成加密遷移）。
/// 2. 已有身份但未解鎖 → `/lock`（記憶體中沒有任何秘密）。
/// 3. 已解鎖 → 進入主殼層；此時不允許停留在引導 / 鎖屏 / 遷移頁。
/// 4. 完全沒有身份 → `/welcome`。
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

      // 1) 舊版明文身份：先完成加密遷移，否則不給進。
      if (core.needsMigration) {
        return isMigrate ? null : '/migrate';
      }

      // 2) 有身份但保險庫不可用（結構毀損）：只能走修復頁。
      if (core.hasIdentity && !core.vaultUsable) {
        return isRecover ? null : '/recover';
      }

      // 3) 已鎖定：只能待在鎖屏。
      if (core.isLocked) {
        return isLock ? null : '/lock';
      }

      // 4) 已解鎖。
      if (core.identity != null) {
        if (isOnboarding || isLock || isMigrate || isRecover) return '/chats';
        return null;
      }

      // 5) 全新使用者。
      return isOnboarding ? null : '/welcome';
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
        builder: (BuildContext context, GoRouterState state) =>
            const RestorePage(),
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
            navigatorKey: _settingsKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/settings',
                builder: (BuildContext context, GoRouterState state) =>
                    const SettingsPage(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'identity',
                    builder: (BuildContext context, GoRouterState state) =>
                        const IdentityPage(),
                  ),
                ],
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
final GlobalKey<NavigatorState> _settingsKey = GlobalKey<NavigatorState>();

/// 讓外部（例如身份刪除）能跳回引導頁。
GlobalKey<NavigatorState> get rootNavigatorKey => _rootKey;

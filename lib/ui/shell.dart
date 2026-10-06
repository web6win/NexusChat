import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/strings.dart';
import '../core/theme/app_theme.dart';
import '../core/update/update_check.dart';
import '../core/update/update_dialog.dart';
import '../state/controllers.dart';

/// 主要壳层：行动装置用底部导览，桌面用左侧导览列。
class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 首次进场后启动轮询。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(chatControllerProvider.notifier).start();
      ref.read(contactsProvider.notifier).refreshKeys();
      // 静默检查版本更新；有更新且使用者没略过这个 build 才弹窗。
      ref.read(updateCheckProvider.notifier).check().then((_) async {
        final checker = ref.read(updateCheckProvider.notifier);
        final auto = await checker.shouldAutoPrompt();
        if (!mounted) return;
        if (auto) showUpdateDialog(context, ref);
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 分页或 App 进背景时系统会把计时器降频（浏览器甚至冻结），
    // 回到前景立刻补一次同步，避免「回来还要等一轮」。
    if (state == AppLifecycleState.resumed) {
      ref.read(chatControllerProvider.notifier).sync();
    }
  }

  void _go(int index) {
    widget.shell.goBranch(
      index,
      initialLocation: index == widget.shell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;

    final destinations = <_Destination>[
      _Destination(Icons.forum_rounded, Icons.forum_outlined, s.navChats),
      _Destination(Icons.people_rounded, Icons.people_outline_rounded, s.navContacts),
      _Destination(Icons.account_balance_wallet_rounded,
          Icons.account_balance_wallet_outlined, s.navWallet),
      _Destination(Icons.explore_rounded, Icons.explore_outlined, s.navDiscover),
      _Destination(Icons.person_rounded, Icons.person_outline_rounded, s.navMe),
    ];

    if (isWide) {
      return Scaffold(
        body: Row(
          children: <Widget>[
            SafeArea(
              child: _WideRail(
                destinations: destinations,
                currentIndex: widget.shell.currentIndex,
                onTap: _go,
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: widget.shell),
          ],
        ),
      );
    }

    return Scaffold(
      body: widget.shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.shell.currentIndex,
        onDestinationSelected: _go,
        destinations: <Widget>[
          for (final d in destinations)
            NavigationDestination(
              icon: Icon(d.outline),
              selectedIcon: Icon(d.filled),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

class _Destination {
  const _Destination(this.filled, this.outline, this.label);

  final IconData filled;
  final IconData outline;
  final String label;
}

class _WideRail extends StatelessWidget {
  const _WideRail({
    required this.destinations,
    required this.currentIndex,
    required this.onTap,
  });

  final List<_Destination> destinations;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    return SizedBox(
      width: 228,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 16, 18),
            child: Row(
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: const Icon(
                    Icons.hub_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        s.appName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Waku · DID',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color:
                              theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: onTap,
              labelType: NavigationRailLabelType.all,
              destinations: <NavigationRailDestination>[
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.outline),
                    selectedIcon: Icon(d.filled),
                    label: Text(d.label),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _NetworkBadge(),
          ),
        ],
      ),
    );
  }
}

/// 显示目前 Waku 连线状态的小徽章。
///
/// 有三种状态，避免「REST 通了就一直显示已连线」的误导：
/// - 节点可达且已入网 → 已连线
/// - 节点可达但没有 peer → 节点无 peer（发布会回 200，但讯息不会被转发）
/// - 节点不可达 → 离线
///
/// 滑过徽章可看到实际连线的节点位址；无 peer 时一并提示原因。
/// 节点是否入网会随服务端改变，因此每 20 秒重测一次。
class _NetworkBadge extends ConsumerStatefulWidget {
  const _NetworkBadge();

  @override
  ConsumerState<_NetworkBadge> createState() => _NetworkBadgeState();
}

class _NetworkBadgeState extends ConsumerState<_NetworkBadge> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => ref.invalidate(networkStatusProvider),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final settings = ref.watch(settingsProvider);
    final health = ref.watch(networkStatusProvider);
    final value = health.value;
    final ok = value?.ok ?? false;
    final noPeers = ok && !(value?.relayReady ?? true);

    final Color color;
    final IconData icon;
    final String label;
    if (!ok) {
      color = AppColors.warning;
      icon = Icons.cloud_queue_rounded;
      label = s.statusOffline;
    } else if (noPeers) {
      color = AppColors.danger;
      icon = Icons.cloud_off_rounded;
      label = s.statusNoPeers;
    } else {
      color = AppColors.success;
      icon = Icons.cloud_done_rounded;
      label = s.statusConnected;
    }

    return Tooltip(
      message: <String>[
        settings.resolvedActiveNodeUrl,
        if (noPeers) s.statusNoPeersHint,
      ].join('\n'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

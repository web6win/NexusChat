import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/app_settings.dart' show AppSettings;
import '../../data/waku/node_probe.dart' show NodeStatus;
import '../../shared/feedback.dart';
import '../../shared/layout.dart';
import '../../shared/widgets.dart';
import '../../state/controllers.dart';

/// 网路：Waku 节点管理、连线测试、重新同步。拆自原本挤在同一页的设定。
class NetworkSettingsPage extends ConsumerStatefulWidget {
  const NetworkSettingsPage({super.key});

  @override
  ConsumerState<NetworkSettingsPage> createState() =>
      _NetworkSettingsPageState();
}

class _NetworkSettingsPageState extends ConsumerState<NetworkSettingsPage> {
  bool _probing = false;
  bool _resyncing = false;

  /// 重新探测所有节点的连线状态。
  Future<void> _recheckNodes() async {
    setState(() => _probing = true);
    ref.invalidate(nodeStatusProvider);
    try {
      await ref.read(nodeStatusProvider.future);
      ref.invalidate(networkStatusProvider);
    } catch (_) {
      // 探测失败只反映在清单状态上，这里不再额外提示。
    } finally {
      if (mounted) setState(() => _probing = false);
    }
  }

  /// 新增自订节点。
  Future<void> _addNode() async {
    final s = context.s;
    final controller = TextEditingController();
    String? error;

    final added = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(s.settingsNodeAddTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: s.settingsWakuNode,
              hintText: s.settingsNodeAddHint,
              errorText: error,
              prefixIcon: const Icon(Icons.hub_rounded),
            ),
            onChanged: (_) {
              if (error != null) setDialogState(() => error = null);
            },
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.cancel),
            ),
            FilledButton(
              onPressed: () async {
                final code = await ref
                    .read(settingsProvider.notifier)
                    .addNode(controller.text);
                if (!context.mounted) return;
                if (code != null) {
                  setDialogState(() {
                    error = code == 'duplicate'
                        ? s.settingsNodeDuplicate
                        : s.settingsNodeInvalid;
                  });
                  return;
                }
                Navigator.pop(context, true);
              },
              child: Text(s.save),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    if (added != true || !mounted) return;
    await _recheckNodes();
    if (!mounted) return;
    showAppSnack(context, s.settingsNodeAdded);
  }

  /// 移除自订节点（内建节点不可移除）。
  Future<void> _removeNode(String url) async {
    final s = context.s;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(s.settingsNodeRemove),
            content: Text(s.settingsNodeRemoveConfirm(url)),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(s.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  s.delete,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    await ref.read(settingsProvider.notifier).removeNode(url);
    await _recheckNodes();
  }

  /// 从节点 store 重新补拉最近错过的讯息与金钥包。
  Future<void> _resync() async {
    setState(() => _resyncing = true);
    try {
      await ref.read(chatControllerProvider.notifier).resyncHistory();
      await ref.read(contactsProvider.notifier).refreshKeys();
    } finally {
      if (mounted) setState(() => _resyncing = false);
    }
    if (!mounted) return;
    showAppSnack(context, context.s.settingsResyncDone);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.settingsNetwork)),
      body: SafeArea(
        bottom: false,
        child: ContentColumn(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: <Widget>[
              SectionCard(
                title: s.settingsNetwork,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            s.settingsWakuNode,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addNode,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(s.settingsNodeAdd),
                        ),
                      ],
                    ),
                    Text(
                      s.settingsNodesDesc,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.45,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // 节点清单：点选可切换「使用中」的节点；内建节点不可移除。
                    for (final url in settings.nodeUrls) ...<Widget>[
                      _NodeTile(
                        key: ValueKey<String>(url),
                        url: url,
                        active: url == settings.activeNodeUrl,
                        onSelect: () => ref
                            .read(settingsProvider.notifier)
                            .setActiveNode(url),
                        onRemove: AppSettings.isBuiltinNode(url)
                            ? null
                            : () => _removeNode(url),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _probing ? null : _recheckNodes,
                        icon: _probing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.network_check_rounded, size: 18),
                        label: Text(s.settingsWakuTest),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _resyncing ? null : _resync,
                        icon: _resyncing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sync_rounded, size: 18),
                        label: Text(s.settingsResync),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.settingsResyncDesc,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.55),
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

/// 单一 Waku 节点的列表项：位址、连线状态、是否使用中，以及（自订节点的）移除按钮。
///
/// 一次只连线一台节点，所以点选列表项就会切换实际连线的对象。
class _NodeTile extends ConsumerWidget {
  const _NodeTile({
    super.key,
    required this.url,
    required this.active,
    required this.onSelect,
    required this.onRemove,
  });

  final String url;

  /// 是否为目前使用中的节点。
  final bool active;

  /// 点选列表项时切换使用中的节点。
  final VoidCallback onSelect;

  /// 仅自订节点会提供；内建节点传入 null 表示不可移除。
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.s;
    final theme = Theme.of(context);
    final statuses = ref.watch(nodeStatusProvider);
    final builtin = AppSettings.isBuiltinNode(url);
    final byUrl = <String, NodeStatus>{
      for (final item in statuses.value ?? const <NodeStatus>[]) item.url: item,
    };
    final status = byUrl[url];

    final Color color;
    final String label;
    if (statuses.isLoading && status == null) {
      color = theme.colorScheme.onSurface.withValues(alpha: 0.45);
      label = s.settingsNodeChecking;
    } else if (status == null) {
      color = theme.colorScheme.onSurface.withValues(alpha: 0.45);
      label = s.settingsNodeChecking;
    } else if (status.ok && !status.relayReady) {
      // 可连线但没有 peer：讯息其实送不出去，不该显示成绿灯。
      color = AppColors.danger;
      label = status.latencyMs == null
          ? s.statusNoPeers
          : '${s.statusNoPeers} · ${status.latencyMs}ms';
    } else if (status.ok) {
      color = AppColors.success;
      label = status.latencyMs == null
          ? s.settingsWakuOk
          : '${s.settingsWakuOk} · ${status.latencyMs}ms';
    } else {
      color = AppColors.danger;
      label = s.settingsWakuFail;
    }

    return InkWell(
      onTap: active ? null : onSelect,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          color: active ? AppColors.brand.withValues(alpha: 0.08) : null,
          border: Border.all(
            color: active
                ? AppColors.brand
                : theme.colorScheme.onSurface.withValues(alpha: 0.12),
            width: active ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              active ? Icons.radio_button_checked_rounded : Icons.hub_rounded,
              size: 18,
              color: active ? AppColors.brand : color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: MonoText(
                          url,
                          maxLines: 1,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Pill(
                        label: builtin
                            ? s.settingsNodeBuiltin
                            : s.settingsNodeCustom,
                        color: builtin
                            ? AppColors.brand
                            : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: <Widget>[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (active) ...<Widget>[
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 13,
                          color: AppColors.brand,
                        ),
                        const SizedBox(width: 5),
                      ],
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: active ? AppColors.brand : color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onRemove != null)
              IconButton(
                tooltip: s.settingsNodeRemove,
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}

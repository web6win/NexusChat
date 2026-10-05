import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/crypto/did.dart';
import '../../data/models/chat_models.dart';
import '../../shared/feedback.dart';
import '../../shared/widgets.dart';
import '../../state/controllers.dart';

/// 群組資訊頁：查看成員、邀請新成員、複製群組 ID、退出或刪除群組。
class GroupInfoPage extends ConsumerStatefulWidget {
  const GroupInfoPage({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends ConsumerState<GroupInfoPage> {
  final Set<String> _picked = <String>{};

  String _displayName(String did, String myDid, List<Contact> contacts, Strings s) {
    if (did.toLowerCase() == myDid.toLowerCase()) return s.groupYou;
    final match = contacts.where((c) => c.did.toLowerCase() == did.toLowerCase());
    if (match.isNotEmpty) return match.first.name;
    return Did.shortDid(did);
  }

  Color _memberColor(String did, List<Contact> contacts) {
    final match = contacts.where((c) => c.did.toLowerCase() == did.toLowerCase());
    return match.isNotEmpty ? match.first.accent : AppColors.brand;
  }

  Future<void> _addMembers() async {
    final group = ref.read(chatControllerProvider).groups
        .where((g) => g.id == widget.groupId)
        .toList();
    if (group.isEmpty) return;
    final members = group.first.memberDids;
    final candidates = ref
        .read(contactsProvider)
        .where((c) => !members.contains(c.did.toLowerCase()))
        .toList();
    if (candidates.isEmpty) {
      if (mounted) showAppSnack(context, context.s.groupNoContacts);
      return;
    }

    _picked.clear();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: Text(context.s.groupAddMember),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: candidates.length,
              itemBuilder: (context, index) {
                final c = candidates[index];
                return CheckboxListTile(
                  value: _picked.contains(c.did),
                  onChanged: (v) => setInner(() {
                    if (v == true) {
                      _picked.add(c.did);
                    } else {
                      _picked.remove(c.did);
                    }
                  }),
                  title: Text(c.name),
                  subtitle: Text(c.did),
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.s.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, _picked.isNotEmpty),
              child: Text(context.s.groupAddMember),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    final controller = ref.read(chatControllerProvider.notifier);
    for (final did in _picked) {
      await controller.addGroupMember(widget.groupId, did);
    }
    if (mounted) showAppSnack(context, context.s.groupAddMember);
  }

  Future<void> _leave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.s.groupLeaveTitle),
        content: Text(context.s.groupLeaveConfirm),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              context.s.leave,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(chatControllerProvider.notifier).leaveGroup(widget.groupId);
    if (mounted) {
      showAppSnack(context, context.s.groupLeft);
      context.go('/chats');
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.s.groupDeleteTitle),
        content: Text(context.s.groupDeleteConfirm),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              context.s.delete,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(chatControllerProvider.notifier).deleteGroup(widget.groupId);
    if (mounted) context.go('/chats');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final myDid = ref.watch(coreProvider).did;
    final contacts = ref.watch(contactsProvider);
    final group = ref
        .watch(chatControllerProvider)
        .groups
        .where((g) => g.id == widget.groupId)
        .toList();
    final theme = Theme.of(context);

    if (group.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(s.groupInfo)),
        body: Center(child: Text(s.groupLeft)),
      );
    }
    final g = group.first;

    return Scaffold(
      appBar: AppBar(title: Text(s.groupInfo)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Row(
            children: <Widget>[
              AppAvatar(name: g.name, color: AppColors.brand, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      g.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.groupMembers(g.memberDids.length),
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.copy_rounded),
            title: Text(s.groupIdCopied),
            subtitle: Text(g.id),
            onTap: () {
              // 複製群組 ID 到剪貼簿。
              Clipboard.setData(ClipboardData(text: g.id));
              if (mounted) showAppSnack(context, s.copied);
            },
          ),
          const SizedBox(height: 8),
          Text(
            s.groupMembersLabel,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          for (final did in g.memberDids)
            ListTile(
              leading: AppAvatar(
                name: _displayName(did, myDid, contacts, s),
                color: _memberColor(did, contacts),
                size: 36,
              ),
              title: Text(_displayName(did, myDid, contacts, s)),
              subtitle: did.toLowerCase() == g.creatorDid.toLowerCase()
                  ? Text(s.groupCreator)
                  : null,
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _addMembers,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: Text(s.groupAddMember),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _leave,
            icon: const Icon(Icons.exit_to_app_rounded),
            label: Text(s.leave),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(s.delete),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}

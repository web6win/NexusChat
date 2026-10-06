import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../data/crypto/did.dart';
import '../../data/models/chat_models.dart';
import '../../data/models/group_models.dart';
import '../../shared/layout.dart';
import '../../shared/widgets.dart';
import '../../state/controllers.dart';
import 'chat_view.dart';

/// 对话列表页；宽萤幕时右侧同时展开对话内容。
class ChatsPage extends ConsumerStatefulWidget {
  const ChatsPage({this.peerDid, this.groupId, super.key});

  /// 由网址 `?peer=` 带入的对话（宽萤幕用于右栏）。
  final String? peerDid;

  /// 由网址 `?group=` 带入的群组对话。
  final String? groupId;

  @override
  ConsumerState<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends ConsumerState<ChatsPage> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    // 与壳层共用同一个门槛：导览列改成左侧时，对话清单也改为双栏。
    final isWide = AppBreakpoints.usesRail(context);
    final state = ref.watch(chatControllerProvider);
    final contacts = ref.watch(contactsProvider);

    final groups = state.groups.where((g) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return g.name.toLowerCase().contains(q) ||
          g.lastText.toLowerCase().contains(q);
    }).toList();

    final conversations = state.conversations.where((c) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return c.title.toLowerCase().contains(q) ||
          c.lastText.toLowerCase().contains(q) ||
          c.peerDid.toLowerCase().contains(q);
    }).toList();

    final list = _ConversationList(
      groups: groups,
      conversations: conversations,
      contacts: contacts,
      searchController: _search,
      onQueryChanged: (value) => setState(() => _query = value),
      selectedPeerDid: widget.peerDid,
      selectedGroupId: widget.groupId,
      onSelect: (did) => context.go('/chats?peer=${Uri.encodeComponent(did)}'),
      onSelectGroup: (id) => context.go('/chats?group=${Uri.encodeComponent(id)}'),
    );

    if (isWide) {
      return Scaffold(
        body: Row(
          children: <Widget>[
            SizedBox(width: AppBreakpoints.conversationList, child: list),
            const VerticalDivider(width: 1),
            Expanded(
              child: widget.groupId != null
                  ? ChatView(
                      key: ValueKey('g-${widget.groupId}'),
                      groupId: widget.groupId!,
                    )
                  : widget.peerDid != null
                      ? ChatView(
                          key: ValueKey(widget.peerDid),
                          peerDid: widget.peerDid!,
                        )
                      : EmptyState(
                          icon: Icons.forum_rounded,
                          title: s.chatPickContact,
                          description: s.chatEmptyDesc,
                        ),
            ),
          ],
        ),
      );
    }

    // 对话必须留在壳层内（宽萤幕左右分栏要用），所以它是同一个路由的
    // query 变化、没有自己的返回堆叠。这里拦下实体返回键与手势返回，
    // 让它等同左上返回箭头：回到对话清单。
    if (widget.groupId != null) {
      return PopScope<Object?>(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) context.go('/chats');
        },
        child: ChatView(
          key: ValueKey('g-${widget.groupId}'),
          groupId: widget.groupId!,
          showBack: true,
          onBack: () => context.go('/chats'),
        ),
      );
    }

    if (widget.peerDid != null) {
      return PopScope<Object?>(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) context.go('/chats');
        },
        child: ChatView(
          key: ValueKey(widget.peerDid),
          peerDid: widget.peerDid!,
          showBack: true,
          onBack: () => context.go('/chats'),
        ),
      );
    }

    return Scaffold(
      body: list,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/contacts'),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(s.contactsAdd),
      ),
    );
  }
}

class _ConversationList extends ConsumerWidget {
  const _ConversationList({
    required this.groups,
    required this.conversations,
    required this.contacts,
    required this.searchController,
    required this.onQueryChanged,
    required this.onSelect,
    required this.onSelectGroup,
    this.selectedPeerDid,
    this.selectedGroupId,
  });

  final List<GroupChat> groups;
  final List<Conversation> conversations;
  final List<Contact> contacts;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onSelectGroup;
  final String? selectedPeerDid;
  final String? selectedGroupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.s;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ContentColumn(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              PageHeader(
                title: s.chatTitle,
                padding: const EdgeInsets.fromLTRB(20, 10, 12, 8),
                actions: <Widget>[
                  IconButton(
                    tooltip: s.groupCreate,
                    // push 而非 go：保留返回堆叠，才有左上返回箭头与返回键可用。
                    onPressed: () => context.push('/group-create'),
                    icon: const Icon(Icons.group_add_rounded),
                  ),
                  IconButton(
                    tooltip: s.refresh,
                    onPressed: () async {
                      ref.invalidate(networkStatusProvider);
                      await ref.read(chatControllerProvider.notifier).sync();
                    },
                    icon: const Icon(Icons.sync_rounded),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: TextField(
                  controller: searchController,
                  onChanged: onQueryChanged,
                  decoration: InputDecoration(
                    hintText: s.chatSearch,
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    isDense: true,
                  ),
                ),
              ),
              if (groups.isEmpty && conversations.isEmpty)
                Expanded(
                  child: EmptyState(
                    icon: Icons.forum_outlined,
                    title: s.chatEmpty,
                    description: s.chatEmptyDesc,
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 96),
                    children: <Widget>[
                      if (groups.isNotEmpty) ...<Widget>[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 16, 4),
                          child: Text(
                            s.groupTitle,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        for (final group in groups)
                          _ConversationTile(
                            group: group,
                            selected: selectedGroupId == group.id,
                            onTap: () => onSelectGroup(group.id),
                          ),
                        Divider(
                          height: 1,
                          indent: 20,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.06),
                        ),
                      ],
                      for (final conversation in conversations)
                        _ConversationTile(
                          conversation: conversation,
                          color: _avatarColor(conversation.peerDid, contacts),
                          selected: selectedPeerDid != null &&
                              selectedPeerDid == conversation.peerDid,
                          onTap: () => onSelect(conversation.peerDid),
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

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    this.conversation,
    this.group,
    this.color,
    this.selected = false,
    required this.onTap,
  });

  final Conversation? conversation;
  final GroupChat? group;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final isGroup = group != null;
    final title = isGroup ? group!.name : conversation!.title;
    final lastText = isGroup ? group!.lastText : conversation!.lastText;
    final lastMedia = isGroup ? group!.lastMedia : conversation!.lastMedia;
    final lastTsMs = isGroup ? group!.lastTsMs : conversation!.lastTsMs;
    final peerKey = isGroup ? group!.peerKey : conversation!.peerDid;
    final unread = isGroup ? group!.unread : conversation!.unread;
    final accent = color ?? AppColors.brand;
    final unreadActive = unread > 0;

    return Material(
      color: selected
          ? AppColors.brand.withValues(alpha: 0.1)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: <Widget>[
              AppAvatar(
                name: title,
                color: accent,
                size: 50,
                showPresence: !isGroup,
                present: true,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: unreadActive
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          lastTsMs == 0
                              ? ''
                              : Formatters.conversationTime(
                                  DateTime.fromMillisecondsSinceEpoch(lastTsMs),
                                  s,
                                ),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.42),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        if (isGroup)
                          Icon(
                            Icons.group_rounded,
                            size: 13,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.45),
                          ),
                        if (isGroup) const SizedBox(width: 4),
                        Icon(
                          Icons.lock_rounded,
                          size: 11,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Row(
                            children: <Widget>[
                              if (lastMedia != null) ...<Widget>[
                                Icon(
                                  lastMedia == 'image'
                                      ? Icons.image_rounded
                                      : Icons.mic_rounded,
                                  size: 14,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                                const SizedBox(width: 4),
                              ],
                              Expanded(
                                child: Text(
                                  _conversationPreview(
                                    lastText,
                                    lastMedia,
                                    peerKey,
                                    s,
                                    isGroup: isGroup,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: unreadActive
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: theme.colorScheme.onSurface
                                        .withValues(
                                            alpha: unreadActive ? 0.78 : 0.55),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (unreadActive) ...<Widget>[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: const BoxDecoration(
                              color: AppColors.brand,
                              borderRadius:
                                  BorderRadius.all(Radius.circular(999)),
                            ),
                            child: Text(
                              '$unread',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
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

/// 对话列表中的最后一则预览文字；媒体讯息显示对应标签。
String _conversationPreview(
  String lastText,
  String? lastMedia,
  String fallbackId,
  Strings s, {
  bool isGroup = false,
}) {
  if (lastMedia == null) {
    if (lastText.isEmpty) return isGroup ? '' : Did.shortDid(fallbackId);
    return lastText;
  }
  final label = lastMedia == 'image' ? s.chatImage : s.chatVoice;
  return lastText.isNotEmpty ? lastText : label;
}

Color _avatarColor(String peerDid, List<Contact> contacts) {
  for (final contact in contacts) {
    if (contact.did.toLowerCase() == peerDid.toLowerCase()) {
      return contact.accent;
    }
  }
  return AppColors.brand;
}

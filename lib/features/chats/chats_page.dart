import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../data/crypto/did.dart';
import '../../data/models/chat_models.dart';
import '../../shared/layout.dart';
import '../../shared/widgets.dart';
import '../../state/controllers.dart';
import 'chat_view.dart';

/// 對話列表頁；寬螢幕時右側同時展開對話內容。
class ChatsPage extends ConsumerStatefulWidget {
  const ChatsPage({this.peerDid, super.key});

  /// 由網址 `?peer=` 帶入的對話（寬螢幕用於右欄）。
  final String? peerDid;

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
    // 與殼層共用同一個門檻：導覽列改成左側時，對話清單也改為雙欄。
    final isWide = AppBreakpoints.usesRail(context);
    final state = ref.watch(chatControllerProvider);
    final contacts = ref.watch(contactsProvider);

    final conversations = state.conversations.where((c) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return c.title.toLowerCase().contains(q) ||
          c.lastText.toLowerCase().contains(q) ||
          c.peerDid.toLowerCase().contains(q);
    }).toList();

    final list = _ConversationList(
      conversations: conversations,
      contacts: contacts,
      searchController: _search,
      onQueryChanged: (value) => setState(() => _query = value),
      selectedPeerDid: widget.peerDid,
      onSelect: (did) => context.go('/chats?peer=${Uri.encodeComponent(did)}'),
    );

    if (isWide) {
      return Scaffold(
        body: Row(
          children: <Widget>[
            SizedBox(width: AppBreakpoints.conversationList, child: list),
            const VerticalDivider(width: 1),
            Expanded(
              child: widget.peerDid != null
                  ? ChatView(key: ValueKey(widget.peerDid), peerDid: widget.peerDid!)
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

    if (widget.peerDid != null) {
      return ChatView(
        key: ValueKey(widget.peerDid),
        peerDid: widget.peerDid!,
        showBack: true,
        onBack: () => context.go('/chats'),
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
    required this.conversations,
    required this.contacts,
    required this.searchController,
    required this.onQueryChanged,
    required this.onSelect,
    this.selectedPeerDid,
  });

  final List<Conversation> conversations;
  final List<Contact> contacts;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onSelect;
  final String? selectedPeerDid;

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
              if (conversations.isEmpty)
                Expanded(
                  child: EmptyState(
                    icon: Icons.forum_outlined,
                    title: s.chatEmpty,
                    description: s.chatEmptyDesc,
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: conversations.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      indent: 82,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                    ),
                    itemBuilder: (context, index) {
                      final conversation = conversations[index];
                      final contact = contacts
                          .where((c) =>
                              c.did.toLowerCase() ==
                              conversation.peerDid.toLowerCase())
                          .toList();
                      final selected = selectedPeerDid != null &&
                          selectedPeerDid == conversation.peerDid;
                      return _ConversationTile(
                        conversation: conversation,
                        color: contact.isNotEmpty
                            ? contact.first.accent
                            : AppColors.brand,
                        selected: selected,
                        onTap: () => onSelect(conversation.peerDid),
                      );
                    },
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
    required this.conversation,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Conversation conversation;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final unread = conversation.unread > 0;

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
                name: conversation.title,
                color: color,
                size: 50,
                showPresence: true,
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
                            conversation.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight:
                                  unread ? FontWeight.w800 : FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          conversation.lastTsMs == 0
                              ? ''
                              : Formatters.conversationTime(
                                  DateTime.fromMillisecondsSinceEpoch(
                                    conversation.lastTsMs,
                                  ),
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
                              if (conversation.lastMedia != null) ...<Widget>[
                                Icon(
                                  conversation.lastMedia == 'image'
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
                                  _conversationPreview(conversation, s),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: unread
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: unread ? 0.78 : 0.55),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (unread) ...<Widget>[
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
                              '${conversation.unread}',
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

/// 對話列表中的最後一則預覽文字；媒體訊息顯示對應標籤。
String _conversationPreview(Conversation conversation, Strings s) {
  if (conversation.lastMedia == null) {
    return conversation.lastText.isEmpty
        ? Did.shortDid(conversation.peerDid)
        : conversation.lastText;
  }
  final label =
      conversation.lastMedia == 'image' ? s.chatImage : s.chatVoice;
  return conversation.lastText.isNotEmpty ? conversation.lastText : label;
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/crypto/did.dart';
import '../../data/models/chat_models.dart';
import '../../shared/feedback.dart';
import '../../shared/layout.dart';
import '../../shared/widgets.dart';
import '../../state/controllers.dart';

/// 聯絡人頁：新增好友、顯示我的 QR Code、直接開始對話。
class ContactsPage extends ConsumerStatefulWidget {
  const ContactsPage({super.key});

  @override
  ConsumerState<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends ConsumerState<ContactsPage> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _showMyQr() async {
    final s = context.s;
    final did = ref.read(sessionProvider).identity?.did ?? '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) => _MyQrSheet(did: did, title: s.contactsMyQr),
    );
  }

  Future<void> _showAddDialog() async {
    final s = context.s;
    final controller = TextEditingController();
    final nameController = TextEditingController();
    String? error;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(s.contactsAdd),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: controller,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (_) => setState(() => error = null),
                decoration: InputDecoration(
                  labelText: s.contactsDidLabel,
                  hintText: s.contactsPasteDid,
                  prefixIcon: const Icon(Icons.alternate_email_rounded),
                  errorText: error,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: '${s.contactsNickname}（${s.optional}）',
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(s.cancel),
            ),
            FilledButton(
              onPressed: () async {
                final result = await ref
                    .read(contactsProvider.notifier)
                    .add(controller.text, nickname: nameController.text.trim());
                if (!context.mounted) return;
                if (result == null) {
                  Navigator.pop(context);
                  showAppSnack(context, s.contactsAdded);
                } else {
                  setState(
                    () => error = result == 'ens-failed'
                        ? s.errorNetwork
                        : s.contactsInvalidDid,
                  );
                }
              },
              child: Text(s.contactsAdd),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final contacts = ref.watch(contactsProvider);
    final filtered = contacts.where((c) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return c.name.toLowerCase().contains(q) ||
          c.did.toLowerCase().contains(q) ||
          (c.ens ?? '').toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ContentColumn(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              PageHeader(
                title: s.contactsTitle,
                padding: const EdgeInsets.fromLTRB(20, 10, 12, 8),
                actions: <Widget>[
                  IconButton(
                    tooltip: s.contactsMyQr,
                    onPressed: _showMyQr,
                    icon: const Icon(Icons.qr_code_2_rounded),
                  ),
                  IconButton(
                    tooltip: s.refresh,
                    onPressed: () async {
                      final ok = await ref
                          .read(contactsProvider.notifier)
                          .refreshKeys();
                      if (!context.mounted) return;
                      // 有補到金鑰才提示成功；沒有變化或失敗就不打擾使用者，
                      // 失敗原因已由 debugPrint 印到主控台。
                      if (ok) showAppSnack(context, s.contactsKeysSynced);
                    },
                    icon: const Icon(Icons.key_rounded),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: TextField(
                  controller: _search,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: s.chatSearch,
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    isDense: true,
                  ),
                ),
              ),
              if (filtered.isEmpty)
                Expanded(
                  child: EmptyState(
                    icon: Icons.people_outline_rounded,
                    title: s.contactsEmpty,
                    description: s.contactsEmptyDesc,
                    action: FilledButton.icon(
                      onPressed: _showAddDialog,
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: Text(s.contactsAdd),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      indent: 78,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.06),
                    ),
                    itemBuilder: (context, index) =>
                        _ContactTile(contact: filtered[index]),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(s.contactsAdd),
      ),
    );
  }
}

class _ContactTile extends ConsumerWidget {
  const _ContactTile({required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.s;
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: AppAvatar(name: contact.name, color: contact.accent, size: 48),
      title: Row(
        children: <Widget>[
          Flexible(
            child: Text(
              contact.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 3),
          MonoText(Did.shortDid(contact.did)),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Icon(
                contact.hasKey
                    ? Icons.enhanced_encryption_rounded
                    : Icons.hourglass_empty_rounded,
                size: 12,
                color: contact.hasKey ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(width: 4),
              Text(
                contact.hasKey ? s.chatEncrypted : s.statusSyncing,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color:
                      contact.hasKey ? AppColors.success : AppColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
      ),
      onTap: () => context.go(
        '/chats?peer=${Uri.encodeComponent(contact.did)}',
      ),
      onLongPress: () async {
        final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(s.contactsRemove),
                content: Text(s.contactsRemoveConfirm(contact.name)),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(s.cancel),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(s.delete,
                        style: const TextStyle(color: AppColors.danger)),
                  ),
                ],
              ),
            ) ??
            false;
        if (confirmed) {
          await ref.read(contactsProvider.notifier).remove(contact.did);
        }
      },
    );
  }
}

/// 我的 QR Code 底部彈出頁。
class _MyQrSheet extends StatelessWidget {
  const _MyQrSheet({required this.did, required this.title});

  final String did;
  final String title;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: QrImageView(
                    data: did,
                    version: QrVersions.auto,
                    size: 210,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(color: Color(0xFF101320)),
                    dataModuleStyle: const QrDataModuleStyle(
                      color: Color(0xFF101320),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  s.contactsDidLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  did,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontFamily: 'monospace',
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: did));
                          if (context.mounted) {
                            showAppSnack(context, s.copied);
                          }
                        },
                        icon: const Icon(Icons.copy_rounded),
                        label: Text(s.copy),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.check_rounded),
                        label: Text(s.done),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  s.contactsScanHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

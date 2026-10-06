import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../shared/feedback.dart';
import '../../shared/widgets.dart';
import '../../state/controllers.dart';

/// 建立群组：选择联络人并命名，产生共享金钥后把邀请分发给每位成员。
class GroupCreatePage extends ConsumerStatefulWidget {
  const GroupCreatePage({super.key});

  @override
  ConsumerState<GroupCreatePage> createState() => _GroupCreatePageState();
}

class _GroupCreatePageState extends ConsumerState<GroupCreatePage> {
  final TextEditingController _name = TextEditingController();
  final Set<String> _selected = <String>{};
  bool _creating = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty || _selected.isEmpty || _creating) return;
    setState(() => _creating = true);
    try {
      final id = await ref
          .read(chatControllerProvider.notifier)
          .createGroup(name: name, memberDids: _selected.toList());
      if (!mounted) return;
      if (id != null) {
        if (context.mounted) context.go('/chats?group=$id');
      } else {
        if (mounted) showAppSnack(context, context.s.errorGeneric, danger: true);
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final contacts = ref.watch(contactsProvider);
    final nameOk = _name.text.trim().isNotEmpty;
    final canCreate = nameOk && _selected.isNotEmpty && !_creating;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.groupCreate),
        actions: <Widget>[
          TextButton(
            onPressed: canCreate ? _create : null,
            child: _creating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(s.createGroup),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: s.groupName,
                hintText: s.groupNameHint,
              ),
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.done,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              s.contactPickerTitle,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: contacts.isEmpty
                ? Center(child: Text(s.groupNoContacts))
                : ListView.builder(
                    itemCount: contacts.length,
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      final checked = _selected.contains(contact.did);
                      return CheckboxListTile(
                        value: checked,
                        onChanged: (value) => setState(() {
                          if (value == true) {
                            _selected.add(contact.did);
                          } else {
                            _selected.remove(contact.did);
                          }
                        }),
                        title: Text(contact.name),
                        subtitle: Text(contact.did),
                        secondary: AppAvatar(
                          name: contact.name,
                          color: contact.accent,
                          size: 36,
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(s.selectedCount(_selected.length)),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/layout.dart';
import '../../shared/widgets.dart';
import '../../state/controllers.dart';

/// 危险操作：删除本机身份。拆自原本挤在同一页的设定。
class DangerSettingsPage extends ConsumerWidget {
  const DangerSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.s;

    return Scaffold(
      appBar: AppBar(title: Text(s.identityRisk)),
      body: SafeArea(
        bottom: false,
        child: ContentColumn(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: <Widget>[
              SectionCard(
                title: s.identityRisk,
                child: SettingsTile(
                  icon: Icons.delete_forever_rounded,
                  title: s.settingsDelete,
                  danger: true,
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(s.settingsDelete),
                            content: Text(s.settingsDeleteConfirm),
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
                    if (confirmed) {
                      await ref.read(sessionProvider.notifier).wipeIdentity();
                      if (context.mounted) context.go('/welcome');
                    }
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

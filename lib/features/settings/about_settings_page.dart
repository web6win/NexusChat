import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/update/update_check.dart';
import '../../core/update/update_dialog.dart';
import '../../core/version.dart';
import '../../shared/feedback.dart';
import '../../shared/layout.dart';
import '../../shared/widgets.dart';

/// 關於：App 資訊、版本號、檢查更新。拆自原本擠在同一頁的設定。
class AboutSettingsPage extends ConsumerWidget {
  const AboutSettingsPage({super.key});

  /// 「檢查更新」那一列的副標：依目前檢查狀態顯示版本 / 檢查中 / 最新 / 失敗。
  String _updateSubtitle(Strings s, UpdateState st) {
    switch (st.status) {
      case UpdateStatus.idle:
        return AppVersion.display;
      case UpdateStatus.checking:
        return s.updateChecking;
      case UpdateStatus.available:
        final remote = st.remote;
        return remote != null
            ? s.updateVersionLine(remote.version, remote.buildNumber)
            : s.updateAvailableTitle;
      case UpdateStatus.upToDate:
        return s.updateLatest;
      case UpdateStatus.error:
        return s.updateFailed;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.s;

    return Scaffold(
      appBar: AppBar(title: Text(s.settingsAbout)),
      body: SafeArea(
        bottom: false,
        child: ContentColumn(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: <Widget>[
              SectionCard(
                title: s.settingsAbout,
                child: Column(
                  children: <Widget>[
                    const SettingsTile(
                      icon: Icons.info_outline_rounded,
                      title: 'NexusChat',
                      subtitle: 'Waku · did:ethr · AES-256-GCM',
                      onTap: null,
                    ),
                    SettingsTile(
                      icon: Icons.numbers_rounded,
                      title: s.settingsVersion,
                      // 由 CI 以 --dart-define 注入，每次建置自動遞增。
                      subtitle: AppVersion.display,
                      onTap: null,
                    ),
                    SettingsTile(
                      icon: Icons.system_update_rounded,
                      title: s.updateCheck,
                      subtitle: _updateSubtitle(s, ref.watch(updateCheckProvider)),
                      trailing: ref.watch(updateCheckProvider).status ==
                              UpdateStatus.checking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                      onTap: () async {
                        await ref
                            .read(updateCheckProvider.notifier)
                            .check();
                        final st = ref.read(updateCheckProvider);
                        if (st.status == UpdateStatus.available) {
                          showUpdateDialog(context, ref);
                        } else if (st.status == UpdateStatus.upToDate) {
                          showAppSnack(context, s.updateLatest);
                        } else if (st.status == UpdateStatus.error) {
                          showAppSnack(context, s.updateFailed);
                        }
                      },
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

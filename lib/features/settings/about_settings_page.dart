import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

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

  /// GPL-3.0 官方全文（不打包進 App，改連 FSF 的正式頁面）。
  static const String _gplUrl = 'https://www.gnu.org/licenses/gpl-3.0.html';

  /// 倉庫裡的第三方授權清單。
  ///
  /// 刻意不打包進安裝档：清單有 25 KB 且只會在更新依賴時變動，
  /// 直接連 GitHub 上的檔案即可，省下這份體積。
  static const String _thirdPartyLicensesUrl =
      'https://github.com/web6win/NexusChat/blob/main/THIRD_PARTY_LICENSES.md';

  /// 用外部瀏覽器開啟 [url]，失敗時給提示，避免靜默無反應。
  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        showAppSnack(context, context.s.errorGeneric);
      }
    } catch (_) {
      if (context.mounted) showAppSnack(context, context.s.errorGeneric);
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
                    // GPL 建議 GUI 程式在「關於」中提供授權資訊，這裡直接開官方全文。
                    SettingsTile(
                      icon: Icons.balance_rounded,
                      title: s.settingsLicense,
                      subtitle: 'GNU GPL v3.0',
                      onTap: () => _openUrl(context, _gplUrl),
                    ),
                    // 相依套件各有自己的授權；GPL 要求保留這些聲明。
                    // 清單留在倉庫，這裡直接開 GitHub 上的檔案。
                    SettingsTile(
                      icon: Icons.description_outlined,
                      title: s.settingsThirdPartyLicenses,
                      subtitle: 'MIT · BSD-3 · Apache-2.0',
                      onTap: () => _openUrl(context, _thirdPartyLicensesUrl),
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

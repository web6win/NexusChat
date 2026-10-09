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

/// 关于：App 资讯、版本号、检查更新。拆自原本挤在同一页的设定。
class AboutSettingsPage extends ConsumerWidget {
  const AboutSettingsPage({super.key});

  /// 「检查更新」那一列的副标：依目前检查状态显示版本 / 检查中 / 最新 / 失败。
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

  /// GPL-3.0 官方全文（不打包进 App，改连 FSF 的正式页面）。
  static const String _gplUrl = 'https://www.gnu.org/licenses/gpl-3.0.html';

  /// 仓库里的第三方授权清单。
  ///
  /// 刻意不打包进安装档：清单有 25 KB 且只会在更新依赖时变动，
  /// 直接连 GitHub 上的档案即可，省下这份体积。
  static const String _thirdPartyLicensesUrl =
      'https://github.com/web6win/NexusChat/blob/main/THIRD_PARTY_LICENSES.md';

  /// 用外部浏览器开启 [url]，失败时给提示，避免静默无反应。
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
                      // 由 CI 以 --dart-define 注入，每次建置自动递增。
                      subtitle: AppVersion.display,
                      onTap: null,
                    ),
                    // GPL 建议 GUI 程式在「关于」中提供授权资讯，这里直接开官方全文。
                    SettingsTile(
                      icon: Icons.balance_rounded,
                      title: s.settingsLicense,
                      subtitle: 'GNU GPL v3.0',
                      onTap: () => _openUrl(context, _gplUrl),
                    ),
                    // 相依套件各有自己的授权；GPL 要求保留这些声明。
                    // 清单留在仓库，这里直接开 GitHub 上的档案。
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
                        if (!context.mounted) return;
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

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import 'update_check.dart';
import 'web_reload_stub.dart' // 非 web 平台的兜底
    if (dart.library.html) 'web_reload_html.dart'; // web 平台的重新整理實作

/// 彈出「發現新版本」對話框：顯示版本資訊、下載中心 QR，以及「稍後 / 立即更新」。
///
/// 立即更新會依目前平台挑對應的下載網址（Android 直接給通用 APK），
/// 用外部瀏覽器開啟；Android 上使用者下載後需手動允許「未知來源」安裝。
void showUpdateDialog(BuildContext context, WidgetRef ref) {
  final remote = ref.read(updateCheckProvider).remote;
  if (remote == null) return;
  final s = context.s;
  // 網頁版不應引導去下載原生 APK：隱藏 QR、按鈕改為「重新整理頁面」。
  final isWeb = kIsWeb;

  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: <Widget>[
          const Icon(Icons.system_update_alt_rounded, color: AppColors.brand),
          const SizedBox(width: 10),
          Expanded(child: Text(s.updateAvailableTitle)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              s.updateVersionLine(remote.version, remote.buildNumber),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            if (remote.publishedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  s.updatePublished(remote.publishedAt!),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.55),
                  ),
                ),
              ),
            if (isWeb) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                s.updateWebHint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
            ] else ...<Widget>[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: remote.downloadPage,
                  version: QrVersions.auto,
                  size: 168,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                s.scanToDownload,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            ref.read(updateCheckProvider.notifier).rememberSkipped();
            Navigator.of(dialogContext).pop();
          },
          child: Text(s.updateLater),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            // 網頁版由 GitHub Pages 託管，重新整理即為最新版；不應引導去下載
            // 原生 APK——網頁使用者裝 APK 會因簽名不一致而安裝失敗 (-7)。
            if (kIsWeb) {
              reloadPage();
              return;
            }
            // 原生平台：開啟對應平台的下載連結 / 下載中心。
            _launchDownload(context, s, remote);
          },
          child: Text(isWeb ? s.updateRefresh : s.updateNow),
        ),
      ],
    ),
  );
}

/// 原生平台：開啟對應平台的下載連結或下載中心，失敗時以 SnackBar 提示，
/// 避免靜默無反應。網頁版不走這條路（見上方按鈕的 kIsWeb 分支）。
Future<void> _launchDownload(
  BuildContext context,
  Strings s,
  RemoteVersion remote,
) async {
  final url = remote.downloadUrlForCurrentPlatform();
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.updateLaunchFailed)),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.updateLaunchFailed)),
      );
    }
  }
}

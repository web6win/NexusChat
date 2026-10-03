import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import 'update_check.dart';

/// 彈出「發現新版本」對話框：顯示版本資訊、下載中心 QR，以及「稍後 / 立即更新」。
///
/// 立即更新會依目前平台挑對應的下載網址（Android 直接給通用 APK），
/// 用外部瀏覽器開啟；Android 上使用者下載後需手動允許「未知來源」安裝。
void showUpdateDialog(BuildContext context, WidgetRef ref) {
  final remote = ref.read(updateCheckProvider).remote;
  if (remote == null) return;
  final s = context.s;

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
          onPressed: () async {
            final url = remote.downloadUrlForCurrentPlatform();
            Navigator.of(dialogContext).pop();
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: Text(s.updateNow),
        ),
      ],
    ),
  );
}

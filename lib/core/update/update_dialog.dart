import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import 'device_abi.dart';
import 'update_check.dart';
import 'web_reload_stub.dart' // 非 web 平台的兜底
    if (dart.library.html) 'web_reload_html.dart'; // web 平台的重新整理实作

/// 弹出「发现新版本」对话框：显示版本资讯、下载中心 QR，以及「稍后 / 立即更新」。
///
/// 立即更新会依目前平台**与装置架构**挑对应的下载网址（Android 优先给
/// 对应 ABI 的分包，没有才退回通用 APK），用外部浏览器开启；
/// Android 上使用者下载后需手动允许「未知来源」安装。
void showUpdateDialog(BuildContext context, WidgetRef ref) {
  final remote = ref.read(updateCheckProvider).remote;
  if (remote == null) return;
  final s = context.s;
  // 只查一次 ABI：对话框与「立即更新」共用同一个结果，避免重复呼叫通道。
  final abisFuture = DeviceAbi.supportedAbis();
  // 网页版不应引导去下载原生 APK：隐藏 QR、按钮改为「重新整理页面」。
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
            // 网页版由 GitHub Pages 托管，重新整理即为最新版；不应引导去下载
            // 原生 APK——网页使用者装 APK 会因签名不一致而安装失败 (-7)。
            if (kIsWeb) {
              reloadPage();
              return;
            }
            // 原生平台：开启对应平台与架构的下载连结 / 下载中心。
            _launchDownload(context, s, remote, abisFuture);
          },
          child: Text(isWeb ? s.updateRefresh : s.updateNow),
        ),
      ],
    ),
  );
}

/// 原生平台：开启**对应架构**的下载连结（拿不到架构则退回平台通用包，
/// 再退回下载中心），失败时以 SnackBar 提示，避免静默无反应。
/// 网页版不走这条路（见上方按钮的 kIsWeb 分支）。
Future<void> _launchDownload(
  BuildContext context,
  Strings s,
  RemoteVersion remote,
  Future<List<String>> abisFuture,
) async {
  final abis = await abisFuture;
  final url = remote.downloadUrlFor(abis: abis);
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

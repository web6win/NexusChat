import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../version.dart';

/// 遠端版本資訊檔（GitHub Pages 上的 version.json）的網址。
///
/// 預設指向自訂網域；若部署到別的網域，可在建構時以
/// `--dart-define=UPDATE_CHECK_URL=https://.../version.json` 覆寫。
const String updateCheckUrl = String.fromEnvironment(
  'UPDATE_CHECK_URL',
  defaultValue: 'https://nchat.web6.win/version.json',
);

/// 「已略過此版本」的偏好鍵：使用者點「稍後」後，同 build 不再自動彈窗。
const String _skippedBuildKey = 'update_skipped_build';

/// 遠端 version.json 解析結果。
class RemoteVersion {
  const RemoteVersion({
    required this.version,
    required this.buildNumber,
    required this.downloadPage,
    required this.downloads,
    this.publishedAt,
  });

  factory RemoteVersion.fromJson(Map<String, dynamic> json) {
    final downloadsRaw = json['downloads'];
    final downloads = <String, String>{};
    if (downloadsRaw is Map) {
      downloadsRaw.forEach((k, v) {
        if (k is String && v is String) downloads[k] = v;
      });
    }
    return RemoteVersion(
      version: json['version']?.toString() ?? '0.0.0',
      buildNumber: int.tryParse(json['build_number']?.toString() ?? '') ?? 0,
      downloadPage: json['download_page']?.toString() ?? updateCheckUrl,
      downloads: downloads,
      publishedAt: json['published_at']?.toString(),
    );
  }

  final String version;
  final int buildNumber;
  final String downloadPage;
  final Map<String, String> downloads;
  final String? publishedAt;

  /// 依目前平台挑一個最合適的下載網址：Android 直接給通用 APK，
  /// 其它平台退回整個下載中心頁。Web 沒有獨立安裝包，也退回下載中心。
  String downloadUrlForCurrentPlatform() {
    final url = downloads[currentPlatformKey()];
    return url ?? downloadPage;
  }
}

/// 目前執行平台的 key（對應 version.json 的 downloads 鍵）。
String currentPlatformKey() {
  if (kIsWeb) return 'web';
  if (Platform.isAndroid) return 'android';
  if (Platform.isIOS) return 'ios';
  if (Platform.isWindows) return 'windows';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isLinux) return 'linux';
  return 'unknown';
}

enum UpdateStatus {
  idle,
  checking,
  available,
  upToDate,
  error,
}

class UpdateState {
  const UpdateState({
    this.status = UpdateStatus.idle,
    this.remote,
    this.errorMessage,
  });

  final UpdateStatus status;
  final RemoteVersion? remote;
  final String? errorMessage;

  UpdateState copyWith({
    UpdateStatus? status,
    RemoteVersion? remote,
    String? errorMessage,
  }) =>
      UpdateState(
        status: status ?? this.status,
        remote: remote ?? this.remote,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

/// 版本更新檢查：拉取遠端 version.json，與本機建置號比對。
///
/// 比對只看單調遞增的 build number（AppVersion.build），語義版本號僅供顯示。
/// 網路失敗不拋異常，而是把狀態設為 [UpdateStatus.error]，由 UI 決定是否提示。
final updateCheckProvider =
    StateNotifierProvider<UpdateChecker, UpdateState>(
  (ref) => UpdateChecker(),
);

class UpdateChecker extends StateNotifier<UpdateState> {
  UpdateChecker() : super(const UpdateState());

  /// 是否已對「這個 build」自動提示過（避免每次進 App 都彈窗）。
  bool _autoPrompted = false;

  Future<void> check() async {
    state = state.copyWith(
      status: UpdateStatus.checking,
      errorMessage: null,
    );
    try {
      final response = await http
          .get(Uri.parse(updateCheckUrl))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final remote = RemoteVersion.fromJson(json);

      final localBuild = int.tryParse(AppVersion.build) ?? 0;
      final available = remote.buildNumber > localBuild;

      state = state.copyWith(
        status: available ? UpdateStatus.available : UpdateStatus.upToDate,
        remote: remote,
      );
    } catch (e) {
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// 啟動時的靜默檢查：有更新且使用者沒略過這個 build 才回傳 true。
  Future<bool> shouldAutoPrompt() async {
    if (_autoPrompted) return false;
    if (state.status != UpdateStatus.available || state.remote == null) {
      return false;
    }
    _autoPrompted = true;
    final prefs = await SharedPreferences.getInstance();
    final skipped = prefs.getInt(_skippedBuildKey);
    return skipped != state.remote!.buildNumber;
  }

  /// 使用者選「稍後」：記住這個 build，之後不再自動彈窗。
  Future<void> rememberSkipped() async {
    if (state.remote == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_skippedBuildKey, state.remote!.buildNumber);
  }

  /// 手動檢查後隱藏「有更新」狀態（不再自動彈窗，保留 remote 供對話框讀取）。
  void clearPrompt() {
    if (state.status == UpdateStatus.available) {
      state = state.copyWith(status: UpdateStatus.upToDate);
    }
  }
}

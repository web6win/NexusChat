import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../version.dart';

/// 远端版本资讯档（GitHub Pages 上的 version.json）的网址。
///
/// 预设指向自订网域；若部署到别的网域，可在建构时以
/// `--dart-define=UPDATE_CHECK_URL=https://.../version.json` 覆写。
const String updateCheckUrl = String.fromEnvironment(
  'UPDATE_CHECK_URL',
  defaultValue: 'https://nchat.web6.win/version.json',
);

/// 「已略过此版本」的偏好键：使用者点「稍后」后，同 build 不再自动弹窗。
const String _skippedBuildKey = 'update_skipped_build';

/// 远端 version.json 解析结果。
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

  /// 依目前平台**与装置架构**挑最合适的下载网址。
  ///
  /// 优先顺序：架构专属包 → 平台通用包 → 下载中心页。
  /// Android 会拿 [abis]（见 [DeviceAbi.supportedAbis]，依偏好顺序）去对
  /// `android_arm64_v8a` / `android_armeabi_v7a` / `android_x86_64`，
  /// 全部缺席才退回通用 APK；其它平台直接用平台键。
  /// Web 没有独立安装包，一律回下载中心。
  String downloadUrlFor({List<String> abis = const <String>[]}) {
    for (final key in _candidateKeys(abis)) {
      final url = downloads[key];
      if (url != null && url.isNotEmpty) return url;
    }
    return downloadPage;
  }

  /// 候选的 downloads 键，越前面越合适。
  List<String> _candidateKeys(List<String> abis) {
    final platform = currentPlatformKey();
    if (platform == 'web') return const <String>[];
    if (platform == 'android') {
      final keys = <String>[];
      for (final abi in abis) {
        final key = _androidAbiKeys[abi];
        if (key != null && !keys.contains(key)) keys.add(key);
      }
      // 通用 APK 作为最后手段：任何 ABI 都装得起来，只是体积较大。
      keys.add('android');
      return keys;
    }
    return <String>[platform];
  }
}

/// 目前执行平台的 key（对应 version.json 的 downloads 键）。
String currentPlatformKey() {
  if (kIsWeb) return 'web';
  if (Platform.isAndroid) return 'android';
  if (Platform.isIOS) return 'ios';
  if (Platform.isWindows) return 'windows';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isLinux) return 'linux';
  return 'unknown';
}

/// Android ABI（例如 `arm64-v8a`）→ version.json 的 downloads 键。
///
/// 只列 CI 实际会产生的分包（见 tool/gen_download_index.py）；
/// 其余 ABI（如 `x86`、`armeabi`）没有对应产物，会退回通用 APK。
const Map<String, String> _androidAbiKeys = <String, String>{
  'arm64-v8a': 'android_arm64_v8a',
  'armeabi-v7a': 'android_armeabi_v7a',
  'x86_64': 'android_x86_64',
};

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

/// 版本更新检查：拉取远端 version.json，与本机建置号比对。
///
/// 比对只看单调递增的 build number（AppVersion.build），语义版本号仅供显示。
/// 网路失败不抛异常，而是把状态设为 [UpdateStatus.error]，由 UI 决定是否提示。
final updateCheckProvider =
    StateNotifierProvider<UpdateChecker, UpdateState>(
  (ref) => UpdateChecker(),
);

class UpdateChecker extends StateNotifier<UpdateState> {
  UpdateChecker() : super(const UpdateState());

  /// 是否已对「这个 build」自动提示过（避免每次进 App 都弹窗）。
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

  /// 启动时的静默检查：有更新且使用者没略过这个 build 才回传 true。
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

  /// 使用者选「稍后」：记住这个 build，之后不再自动弹窗。
  Future<void> rememberSkipped() async {
    if (state.remote == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_skippedBuildKey, state.remote!.buildNumber);
  }

  /// 手动检查后隐藏「有更新」状态（不再自动弹窗，保留 remote 供对话框读取）。
  void clearPrompt() {
    if (state.status == UpdateStatus.available) {
      state = state.copyWith(status: UpdateStatus.upToDate);
    }
  }
}

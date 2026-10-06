import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// 取得装置支援的 ABI，让「版本更新」能挑对应架构的安装包，
/// 而不是一律下载通用版（universal APK）。
///
/// 只有 Android 实作了这个 MethodChannel（见 MainActivity.kt）：
/// `Build.SUPPORTED_ABIS` 会依**偏好顺序**回传，例如
/// `['arm64-v8a', 'armeabi-v7a', 'armeabi']`，通常第一个就是最合适的。
///
/// 任何失败（非 Android / 通道未实作 / 例外）都回传空清单，
/// 呼叫方应退回通用安装包——拿不到 ABI 也比下载失败好。
abstract final class DeviceAbi {
  static const MethodChannel _channel = MethodChannel('nexuschat/abi');

  /// 只有 Android 才可能取得 ABI。
  static bool get available => !kIsWeb && Platform.isAndroid;

  /// 依偏好顺序回传装置支援的 ABI；拿不到时回传空清单。
  static Future<List<String>> supportedAbis() async {
    if (!available) return const <String>[];
    try {
      final result =
          await _channel.invokeMethod<List<dynamic>>('supportedAbis');
      if (result == null) return const <String>[];
      return result
          .map((dynamic e) => e?.toString() ?? '')
          .where((String e) => e.isNotEmpty)
          .toList(growable: false);
    } on MissingPluginException {
      return const <String>[];
    } on PlatformException {
      return const <String>[];
    } catch (_) {
      return const <String>[];
    }
  }
}

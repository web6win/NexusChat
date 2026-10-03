import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// 取得裝置支援的 ABI，讓「版本更新」能挑對應架構的安裝包，
/// 而不是一律下載通用版（universal APK）。
///
/// 只有 Android 實作了這個 MethodChannel（見 MainActivity.kt）：
/// `Build.SUPPORTED_ABIS` 會依**偏好順序**回傳，例如
/// `['arm64-v8a', 'armeabi-v7a', 'armeabi']`，通常第一個就是最合適的。
///
/// 任何失敗（非 Android / 通道未實作 / 例外）都回傳空清單，
/// 呼叫方應退回通用安裝包——拿不到 ABI 也比下載失敗好。
abstract final class DeviceAbi {
  static const MethodChannel _channel = MethodChannel('nexuschat/abi');

  /// 只有 Android 才可能取得 ABI。
  static bool get available => !kIsWeb && Platform.isAndroid;

  /// 依偏好順序回傳裝置支援的 ABI；拿不到時回傳空清單。
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

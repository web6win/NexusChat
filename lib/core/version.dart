/// 應用程式版本。
///
/// 版本號由 CI 在建構時以 `--dart-define` 注入（見
/// `.github/workflows/build-and-publish.yml` 的 version 作業），因此**不需要
/// 手動維護**：每次推送到 main，build number 會自動 +1，這裡顯示的值也跟著
/// 更新。
///
/// 沒有注入時（本機 `flutter run`）退回 [fallbackName] / `0`，畫面上只會
/// 顯示版本號而不帶建置號。
class AppVersion {
  const AppVersion._();

  /// dart-define 的鍵：語義版本號。
  static const String nameKey = 'APP_VERSION_NAME';

  /// dart-define 的鍵：建置號。
  static const String buildKey = 'APP_VERSION_BUILD';

  /// 未注入時的語義版本號（應與 pubspec.yaml 的 `version:` 一致）。
  static const String fallbackName = '1.0.0';

  /// 語義版本號，例如 `1.2.3`。
  static const String name =
      String.fromEnvironment(nameKey, defaultValue: fallbackName);

  /// 建置號（單調遞增整數）。未注入時為 `'0'`，代表「本機建置」。
  static const String build =
      String.fromEnvironment(buildKey, defaultValue: '0');

  /// 是否由 CI 注入過。
  static bool get isInjected => build != '0' && build.isNotEmpty;

  /// 顯示用字串：`1.2.3 (42)`；本機建置只顯示 `1.2.3`。
  static String get display =>
      isInjected ? '$name ($build)' : name;
}

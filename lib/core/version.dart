/// 应用程式版本。
///
/// 版本号由 CI 在建构时以 `--dart-define` 注入（见
/// `.github/workflows/build-and-publish.yml` 的 version 作业），因此**不需要
/// 手动维护**：每次推送到 main，build number 会自动 +1，这里显示的值也跟著
/// 更新。
///
/// 没有注入时（本机 `flutter run`）退回 [fallbackName] / `0`，画面上只会
/// 显示版本号而不带建置号。
class AppVersion {
  const AppVersion._();

  /// dart-define 的键：语义版本号。
  static const String nameKey = 'APP_VERSION_NAME';

  /// dart-define 的键：建置号。
  static const String buildKey = 'APP_VERSION_BUILD';

  /// 未注入时的语义版本号（应与 pubspec.yaml 的 `version:` 一致）。
  static const String fallbackName = '1.0.1';

  /// 语义版本号，例如 `1.2.3`。
  static const String name =
      String.fromEnvironment(nameKey, defaultValue: fallbackName);

  /// 建置号（单调递增整数）。未注入时为 `'0'`，代表「本机建置」。
  static const String build =
      String.fromEnvironment(buildKey, defaultValue: '0');

  /// 是否由 CI 注入过。
  static bool get isInjected => build != '0' && build.isNotEmpty;

  /// 显示用字串：`1.2.3 (42)`；本机建置只显示 `1.2.3`。
  static String get display =>
      isInjected ? '$name ($build)' : name;
}

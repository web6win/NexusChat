import 'package:nexuschat/core/version.dart';
import 'package:test/test.dart';

/// 版本號的顯示邏輯。
///
/// 真正的版本號由 CI 以 `--dart-define` 注入（見 tool/bump_version.dart），
/// 這裡只驗證「沒有注入時」的回退行為 —— 也就是本機 `flutter run` 的情形。
void main() {
  group('AppVersion', () {
    test('未注入時退回預設版本號', () {
      // 測試執行環境沒有帶 dart-define，因此拿到的是預設值。
      expect(AppVersion.name, AppVersion.fallbackName);
      expect(AppVersion.build, '0');
      expect(AppVersion.isInjected, isFalse);
    });

    test('未注入時只顯示版本號，不帶建置號', () {
      expect(AppVersion.display, AppVersion.fallbackName);
      expect(AppVersion.display.contains('('), isFalse);
    });
  });
}

import 'package:nexuschat/core/version.dart';
import 'package:test/test.dart';

/// 版本号的显示逻辑。
///
/// 真正的版本号由 CI 以 `--dart-define` 注入（见 tool/bump_version.dart），
/// 这里只验证「没有注入时」的回退行为 —— 也就是本机 `flutter run` 的情形。
void main() {
  group('AppVersion', () {
    test('未注入时退回预设版本号', () {
      // 测试执行环境没有带 dart-define，因此拿到的是预设值。
      expect(AppVersion.name, AppVersion.fallbackName);
      expect(AppVersion.build, '0');
      expect(AppVersion.isInjected, isFalse);
    });

    test('未注入时只显示版本号，不带建置号', () {
      expect(AppVersion.display, AppVersion.fallbackName);
      expect(AppVersion.display.contains('('), isFalse);
    });
  });
}

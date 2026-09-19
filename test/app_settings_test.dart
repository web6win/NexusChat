import 'package:flutter_test/flutter_test.dart';

import 'package:nexuschat/data/models/app_settings.dart';
import 'package:nexuschat/data/waku/waku_transport.dart';

/// 節點設定與舊版資料遷移的單元測試。
///
/// 這支測試需要 Flutter 綁定，因為 [AppSettings] 依賴 `flutter/material`。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('節點連線設定', () {
    test('預設只連線使用中的那一個節點', () {
      const settings = AppSettings();

      expect(settings.activeNodeUrl, AppSettings.defaultActiveNodeUrl);
      expect(
        settings.resolvedActiveNodeUrl,
        AppSettings.defaultActiveNodeUrl,
      );
    });

    test('切換使用中的節點會改變實際連線的節點', () {
      const settings = AppSettings();
      final switched = settings.copyWith(
        activeNodeUrl: 'https://waku02.web6.win',
      );

      expect(switched.resolvedActiveNodeUrl, 'https://waku02.web6.win');
      // 節點清單本身不變：清單只是候選池，不代表會同時連線。
      expect(switched.nodeUrls, AppSettings.builtinNodeUrls);
    });

    test('使用中的節點不在清單時退回第一台', () {
      final settings = AppSettings.fromJson(<String, dynamic>{
        'activeNodeUrl': 'https://gone.example.com',
        'nodeUrls': <String>['https://waku01.web6.win'],
      });

      expect(settings.activeNodeUrl, 'https://waku01.web6.win');
      expect(settings.resolvedActiveNodeUrl, 'https://waku01.web6.win');
    });
  });

  group('設定持久化', () {
    test('使用中的節點可來回還原', () {
      final saved = AppSettings().copyWith(
        nodeUrls: <String>[
          ...AppSettings.builtinNodeUrls,
          'https://my.node',
        ],
        activeNodeUrl: 'https://my.node',
      );
      final restored = AppSettings.fromJson(saved.toJson());

      expect(restored.activeNodeUrl, 'https://my.node');
      expect(restored.resolvedActiveNodeUrl, 'https://my.node');
      expect(restored.nodeUrls, contains('https://my.node'));
    });

    test('舊版單一 nodeUrl 會併入清單，且沒有記錄使用中節點時取第一台', () {
      final legacy = AppSettings.fromJson(<String, dynamic>{
        'nodeUrl': 'https://legacy.example.com',
      });

      expect(legacy.nodeUrls, contains('https://legacy.example.com'));
      expect(legacy.activeNodeUrl, AppSettings.defaultActiveNodeUrl);
      expect(legacy.nodeUrls.first, AppSettings.defaultActiveNodeUrl);
    });

    test('舊版 loopback 傳輸模式會升級為 nwaku REST', () {
      final legacy = AppSettings.fromJson(<String, dynamic>{
        'transport': 'loopback',
      });

      expect(legacy.transport, TransportKind.nwakuRest);
    });

    test('節點位址會正規化：補 scheme、去尾斜線、拒絕無效值', () {
      expect(
        AppSettings.normalizeNodeUrl('waku01.web6.win/'),
        'https://waku01.web6.win',
      );
      expect(
        AppSettings.normalizeNodeUrl('  https://a.example.com//  '),
        'https://a.example.com',
      );
      expect(AppSettings.normalizeNodeUrl(''), '');
      expect(AppSettings.normalizeNodeUrl('not a url'), '');
    });

    test('內建節點判斷用於禁止刪除', () {
      expect(AppSettings.isBuiltinNode('https://waku01.web6.win'), isTrue);
      expect(AppSettings.isBuiltinNode('https://waku02.web6.win'), isTrue);
      expect(AppSettings.isBuiltinNode('https://my.node'), isFalse);
    });
  });
}

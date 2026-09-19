import 'package:hive_flutter/hive_flutter.dart';

/// 本地鍵值儲存（Hive）。跨平台：原生走檔案系統，Web 走 IndexedDB。
class LocalStore {
  LocalStore._();

  static final LocalStore instance = LocalStore._();

  static const String boxName = 'nexuschat';

  /// 設定。
  static const String kSettings = 'settings';

  /// 身份。
  static const String kIdentity = 'identity';

  /// 加密後的身份保險庫（密文，含助記詞與私鑰）。
  static const String kIdentityVault = 'identity_vault';

  /// 身份的公開提示（明文：did / address / 加密公鑰，皆為公開資訊）。
  static const String kIdentityHint = 'identity_hint';

  /// 安全設定（自動鎖定等）。
  static const String kSecurity = 'security';

  static const String kContactPrefix = 'contact:';
  static const String kConversationPrefix = 'conv:';
  static const String kMessagePrefix = 'msg:';

  Box<dynamic>? _box;

  bool get isReady => _box?.isOpen ?? false;

  Future<void> init() async {
    if (_box?.isOpen ?? false) return;
    await Hive.initFlutter();
    _box = await Hive.openBox<dynamic>(boxName);
  }

  Box<dynamic> get box {
    final b = _box;
    if (b == null || !b.isOpen) {
      throw StateError('LocalStore 尚未初始化，請先呼叫 init()');
    }
    return b;
  }

  Object? read(String key) => box.get(key);

  Future<void> write(String key, Object? value) => box.put(key, value);

  Future<void> delete(String key) => box.delete(key);

  /// 讀出所有符合前綴的值。
  List<Object?> readPrefix(String prefix) {
    final result = <Object?>[];
    for (final key in box.keys) {
      if (key is String && key.startsWith(prefix)) {
        result.add(box.get(key));
      }
    }
    return result;
  }

  /// 刪除所有符合前綴的鍵。
  Future<void> deletePrefix(String prefix) async {
    final keys = box.keys
        .where((k) => k is String && k.startsWith(prefix))
        .toList(growable: false);
    for (final key in keys) {
      await box.delete(key);
    }
  }

  Future<void> clearApp() async {
    await deletePrefix(kContactPrefix);
    await deletePrefix(kConversationPrefix);
    await deletePrefix(kMessagePrefix);
    // 身份三件套一併清除：舊明文、密文保險庫、公開提示。
    await delete(kIdentity);
    await delete(kIdentityVault);
    await delete(kIdentityHint);
    await delete(kSecurity);
  }
}

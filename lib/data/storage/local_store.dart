import 'package:hive_flutter/hive_flutter.dart';

/// 本地键值储存（Hive）。跨平台：原生走档案系统，Web 走 IndexedDB。
class LocalStore {
  LocalStore._();

  static final LocalStore instance = LocalStore._();

  static const String boxName = 'nexuschat';

  /// 设定。
  static const String kSettings = 'settings';

  /// 身份。
  static const String kIdentity = 'identity';

  /// 加密后的身份保险库（密文，含助记词与私钥）。
  static const String kIdentityVault = 'identity_vault';

  /// 身份的公开提示（明文：did / address / 加密公钥，皆为公开资讯）。
  static const String kIdentityHint = 'identity_hint';

  /// 安全设定（自动锁定等）。
  static const String kSecurity = 'security';

  static const String kContactPrefix = 'contact:';
  static const String kConversationPrefix = 'conv:';
  static const String kMessagePrefix = 'msg:';

  /// 群组聊天（`group:<id>` → 群组元资料）。
  static const String kGroupPrefix = 'group:';

  /// 已删除讯息的墓碑（`delmsg:<id>` → 删除时间）。
  static const String kDeletedMessagePrefix = 'delmsg:';

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
      throw StateError('LocalStore 尚未初始化，请先呼叫 init()');
    }
    return b;
  }

  Object? read(String key) => box.get(key);

  Future<void> write(String key, Object? value) => box.put(key, value);

  Future<void> delete(String key) => box.delete(key);

  /// 读出所有符合前缀的值。
  List<Object?> readPrefix(String prefix) {
    final result = <Object?>[];
    for (final key in box.keys) {
      if (key is String && key.startsWith(prefix)) {
        result.add(box.get(key));
      }
    }
    return result;
  }

  /// 删除所有符合前缀的键。
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
    await deletePrefix(kGroupPrefix);
    await deletePrefix(kDeletedMessagePrefix);
    // 身份三件套一并清除：旧明文、密文保险库、公开提示。
    await delete(kIdentity);
    await delete(kIdentityVault);
    await delete(kIdentityHint);
    await delete(kSecurity);
  }
}

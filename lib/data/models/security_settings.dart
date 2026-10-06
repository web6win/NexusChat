import 'package:flutter/foundation.dart' show immutable;

/// 安全相关设定（持久化，但**不含任何秘密**）。
@immutable
class SecuritySettings {
  const SecuritySettings({
    this.autoLockMinutes = 5,
    this.lockOnHide = false,
    this.hideSecretsAfterSeconds = 30,
  });

  /// 闲置多久自动锁定；`0` 表示永不自动锁定（不建议）。
  final int autoLockMinutes;

  /// 页面切到背景（切换分页 / 最小化）时是否立即锁定。
  ///
  /// 预设关闭：在浏览器上频繁切分页是常态，立即锁定会严重干扰使用；
  /// 闲置计时已能覆盖「离开后未回来」的情境。对安全要求高的使用者可开启。
  final bool lockOnHide;

  /// 助记词 / 私钥显示后几秒自动隐藏（防止肩窥与萤幕录制残留）。
  final int hideSecretsAfterSeconds;

  /// 可选的自动锁定分钟数。
  static const List<int> autoLockOptions = <int>[0, 1, 5, 15, 30, 60];

  /// 自动锁定时长；`null` 代表不自动锁定。
  Duration? get autoLockDuration =>
      autoLockMinutes <= 0 ? null : Duration(minutes: autoLockMinutes);

  /// 敏感内容自动隐藏时长。
  Duration get hideSecretsAfter =>
      Duration(seconds: hideSecretsAfterSeconds <= 0 ? 30 : hideSecretsAfterSeconds);

  SecuritySettings copyWith({
    int? autoLockMinutes,
    bool? lockOnHide,
    int? hideSecretsAfterSeconds,
  }) {
    return SecuritySettings(
      autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
      lockOnHide: lockOnHide ?? this.lockOnHide,
      hideSecretsAfterSeconds:
          hideSecretsAfterSeconds ?? this.hideSecretsAfterSeconds,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'autoLockMinutes': autoLockMinutes,
        'lockOnHide': lockOnHide,
        'hideSecretsAfterSeconds': hideSecretsAfterSeconds,
      };

  static SecuritySettings fromJson(Object? raw) {
    if (raw is! Map) return const SecuritySettings();
    final minutes = raw['autoLockMinutes'];
    final hide = raw['hideSecretsAfterSeconds'];
    return SecuritySettings(
      autoLockMinutes:
          minutes is int && minutes >= 0 ? minutes : 5,
      lockOnHide: (raw['lockOnHide'] as bool?) ?? false,
      hideSecretsAfterSeconds:
          hide is int && hide > 0 ? hide : 30,
    );
  }
}

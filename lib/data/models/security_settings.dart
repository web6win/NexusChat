import 'package:flutter/foundation.dart' show immutable;

/// 安全相關設定（持久化，但**不含任何秘密**）。
@immutable
class SecuritySettings {
  const SecuritySettings({
    this.autoLockMinutes = 5,
    this.lockOnHide = false,
    this.hideSecretsAfterSeconds = 30,
  });

  /// 閒置多久自動鎖定；`0` 表示永不自動鎖定（不建議）。
  final int autoLockMinutes;

  /// 頁面切到背景（切換分頁 / 最小化）時是否立即鎖定。
  ///
  /// 預設關閉：在瀏覽器上頻繁切分頁是常態，立即鎖定會嚴重干擾使用；
  /// 閒置計時已能覆蓋「離開後未回來」的情境。對安全要求高的使用者可開啟。
  final bool lockOnHide;

  /// 助記詞 / 私鑰顯示後幾秒自動隱藏（防止肩窺與螢幕錄製殘留）。
  final int hideSecretsAfterSeconds;

  /// 可選的自動鎖定分鐘數。
  static const List<int> autoLockOptions = <int>[0, 1, 5, 15, 30, 60];

  /// 自動鎖定時長；`null` 代表不自動鎖定。
  Duration? get autoLockDuration =>
      autoLockMinutes <= 0 ? null : Duration(minutes: autoLockMinutes);

  /// 敏感內容自動隱藏時長。
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

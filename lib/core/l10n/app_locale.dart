import 'dart:ui' show Locale;

/// 應用程式支援的語系。
enum AppLocale {
  /// 繁體中文（預設）
  zhHant('zh_Hant', '繁體中文', 'Traditional Chinese', Locale('zh', 'TW')),
  /// 简体中文
  zhHans('zh_Hans', '简体中文', 'Simplified Chinese', Locale('zh', 'CN')),
  /// English
  en('en', 'English', 'English', Locale('en')),
  /// Español
  es('es', 'Español', 'Spanish', Locale('es'));

  const AppLocale(this.code, this.nativeName, this.englishName, this.locale);

  /// 穩定識別碼，用於持久化。
  final String code;

  /// 語系自身的名稱（用於語言列表）。
  final String nativeName;

  /// 語系的英文名稱（除錯用）。
  final String englishName;

  /// 對應的 [Locale]。
  final Locale locale;

  static AppLocale fromCode(String? code) {
    for (final l in AppLocale.values) {
      if (l.code == code) return l;
    }
    return AppLocale.zhHant;
  }

  /// 依據系統語系推測最合適的語系，無法匹配時回傳 [AppLocale.zhHant]。
  static AppLocale fromLocale(Locale? locale) {
    if (locale == null) return AppLocale.zhHant;
    final lang = locale.languageCode.toLowerCase();
    final script = locale.scriptCode?.toLowerCase();
    final country = locale.countryCode?.toUpperCase();
    if (lang == 'zh') {
      if (script == 'hans' || country == 'CN' || country == 'SG') {
        return AppLocale.zhHans;
      }
      return AppLocale.zhHant;
    }
    if (lang == 'es') return AppLocale.es;
    if (lang == 'en') return AppLocale.en;
    return AppLocale.zhHant;
  }
}

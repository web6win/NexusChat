import 'dart:ui' show Locale;

/// 應用程式支援的語系。
///
/// 列舉順序同時決定「設定裡的語言列表」與
/// [MaterialApp.supportedLocales] 的排列；英文為預設且排在最前面。
enum AppLocale {
  /// English（預設）
  en('en', 'English', 'English', Locale('en')),
  /// 简体中文
  zhHans('zh_Hans', '简体中文', 'Simplified Chinese', Locale('zh', 'CN')),
  /// Español
  es('es', 'Español', 'Spanish', Locale('es')),
  /// हिन्दी
  hi('hi', 'हिन्दी', 'Hindi', Locale('hi')),
  /// Français
  fr('fr', 'Français', 'French', Locale('fr'));

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
    return AppLocale.en;
  }

  /// 依據系統語系推測最合適的語系，無法匹配時回傳 [AppLocale.en]。
  static AppLocale fromLocale(Locale? locale) {
    if (locale == null) return AppLocale.en;
    final lang = locale.languageCode.toLowerCase();
    // 繁體中文已移除，所有 zh 一律落到簡體中文。
    if (lang == 'zh') return AppLocale.zhHans;
    if (lang == 'es') return AppLocale.es;
    if (lang == 'hi') return AppLocale.hi;
    if (lang == 'fr') return AppLocale.fr;
    return AppLocale.en;
  }
}

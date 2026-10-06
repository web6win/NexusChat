import 'dart:ui' show Locale;

/// 应用程式支援的语系。
///
/// 列举顺序同时决定「设定里的语言列表」与
/// [MaterialApp.supportedLocales] 的排列；英文为预设且排在最前面。
enum AppLocale {
  /// English（预设）
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

  /// 稳定识别码，用于持久化。
  final String code;

  /// 语系自身的名称（用于语言列表）。
  final String nativeName;

  /// 语系的英文名称（除错用）。
  final String englishName;

  /// 对应的 [Locale]。
  final Locale locale;

  static AppLocale fromCode(String? code) {
    for (final l in AppLocale.values) {
      if (l.code == code) return l;
    }
    return AppLocale.en;
  }

  /// 依据系统语系推测最合适的语系，无法匹配时回传 [AppLocale.en]。
  static AppLocale fromLocale(Locale? locale) {
    if (locale == null) return AppLocale.en;
    final lang = locale.languageCode.toLowerCase();
    // 繁体中文已移除，所有 zh 一律落到简体中文。
    if (lang == 'zh') return AppLocale.zhHans;
    if (lang == 'es') return AppLocale.es;
    if (lang == 'hi') return AppLocale.hi;
    if (lang == 'fr') return AppLocale.fr;
    return AppLocale.en;
  }
}

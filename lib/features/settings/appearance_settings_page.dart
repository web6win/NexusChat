import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_locale.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/app_settings.dart' show ThemePreference;
import '../../shared/layout.dart';
import '../../shared/widgets.dart';
import '../../state/controllers.dart';

/// 外觀與語言：主題切換 + 語言選擇。拆自原本擠在同一頁的設定。
class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.s;
    final settings = ref.watch(settingsProvider);
    final locale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.settingsAppearance)),
      body: SafeArea(
        bottom: false,
        child: ContentColumn(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: <Widget>[
              SectionCard(
                title: s.settingsThemeSystem,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: ThemeOptionCard(
                            label: s.settingsThemeLight,
                            icon: Icons.light_mode_rounded,
                            selected: settings.theme == ThemePreference.light,
                            onTap: () => ref
                                .read(settingsProvider.notifier)
                                .setTheme(ThemePreference.light),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ThemeOptionCard(
                            label: s.settingsThemeDark,
                            icon: Icons.dark_mode_rounded,
                            selected: settings.theme == ThemePreference.dark,
                            onTap: () => ref
                                .read(settingsProvider.notifier)
                                .setTheme(ThemePreference.dark),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ThemeOptionCard(
                            label: s.settingsThemeSystem,
                            icon: Icons.brightness_auto_rounded,
                            selected: settings.theme == ThemePreference.system,
                            onTap: () => ref
                                .read(settingsProvider.notifier)
                                .setTheme(ThemePreference.system),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SectionCard(
                title: s.settingsLanguage,
                child: Column(
                  children: <Widget>[
                    SettingsTile(
                      icon: Icons.translate_rounded,
                      title: s.settingsThemeSystem,
                      subtitle: s.settingsLanguage,
                      trailing: locale == null
                          ? const Icon(Icons.check_rounded,
                              color: AppColors.brand)
                          : null,
                      onTap: () =>
                          ref.read(settingsProvider.notifier).setLocaleCode(''),
                    ),
                    for (final item in AppLocale.values)
                      SettingsTile(
                        icon: Icons.language_rounded,
                        title: item.nativeName,
                        subtitle: item.englishName,
                        trailing: locale == item
                            ? const Icon(Icons.check_rounded,
                                color: AppColors.brand)
                            : null,
                        onTap: () => ref
                            .read(settingsProvider.notifier)
                            .setLocaleCode(item.code),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_locale.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/app_settings.dart' show ThemePreference;
import '../../state/controllers.dart';

/// 引導頁：說明價值主張，並讓使用者建立或匯入身份。
class WelcomePage extends ConsumerWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.s;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          // 背景光暈
          Positioned(
            top: -140,
            right: -100,
            child: _Glow(size: 320, color: AppColors.brand, opacity: isDark ? 0.32 : 0.2),
          ),
          Positioned(
            bottom: -160,
            left: -120,
            child: _Glow(size: 340, color: AppColors.accent, opacity: isDark ? 0.24 : 0.16),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            width: 46,
                            height: 46,
                            decoration: const BoxDecoration(
                              gradient: AppColors.brandGradient,
                              borderRadius:
                                  BorderRadius.all(Radius.circular(15)),
                            ),
                            child: const Icon(
                              Icons.hub_rounded,
                              color: Colors.white,
                              size: 25,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  s.appName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                Text(
                                  s.appTagline,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.55),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _LanguageButton(),
                          const SizedBox(width: 4),
                          _ThemeButton(),
                        ],
                      ),
                      const SizedBox(height: 44),
                      Text(
                        s.onboardingTitle,
                        style: const TextStyle(
                          fontSize: 33,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        s.onboardingSubtitle,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.55,
                          color:
                              theme.colorScheme.onSurface.withValues(alpha: 0.62),
                        ),
                      ),
                      const SizedBox(height: 30),
                      _FeatureRow(
                        icon: Icons.hub_rounded,
                        color: AppColors.brand,
                        title: s.feat1Title,
                        description: s.feat1Desc,
                      ),
                      const SizedBox(height: 12),
                      _FeatureRow(
                        icon: Icons.fingerprint_rounded,
                        color: AppColors.accent,
                        title: s.feat2Title,
                        description: s.feat2Desc,
                      ),
                      const SizedBox(height: 12),
                      _FeatureRow(
                        icon: Icons.enhanced_encryption_rounded,
                        color: AppColors.success,
                        title: s.feat3Title,
                        description: s.feat3Desc,
                      ),
                      const SizedBox(height: 36),
                      FilledButton(
                        onPressed: () => context.push('/create'),
                        child: Text(s.onboardingCreate),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => context.push('/restore'),
                        child: Text(s.onboardingImport),
                      ),
                      const SizedBox(height: 26),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color, required this.opacity});

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.07),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12.8,
                    height: 1.45,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 語言切換按鈕（引導頁與設定頁共用）。
class _LanguageButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider);
    return PopupMenuButton<String?>(
      tooltip: context.s.settingsLanguage,
      icon: const Icon(Icons.translate_rounded),
      onSelected: (value) =>
          ref.read(settingsProvider.notifier).setLocaleCode(value ?? ''),
      itemBuilder: (context) => <PopupMenuEntry<String?>>[
        PopupMenuItem<String?>(
          value: '',
          child: _LanguageOption(
            label: context.s.settingsThemeSystem,
            selected: current == null,
          ),
        ),
        for (final locale in AppLocale.values)
          PopupMenuItem<String?>(
            value: locale.code,
            child: _LanguageOption(
              label: locale.nativeName,
              selected: current == locale,
            ),
          ),
      ],
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          size: 18,
          color: selected ? AppColors.brand : null,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.brand : null,
          ),
        ),
      ],
    );
  }
}

/// 主題切換按鈕。
class _ThemeButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(settingsProvider).theme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: context.s.settingsTheme,
      onPressed: () {
        final next = isDark ? ThemePreference.light : ThemePreference.dark;
        ref.read(settingsProvider.notifier).setTheme(next);
      },
      icon: Icon(
        theme == ThemePreference.system
            ? Icons.brightness_auto_rounded
            : (isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
      ),
    );
  }
}

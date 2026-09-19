import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 品牌色票。介面上所有顏色都從這裡出發，方便一次調整整體調性。
abstract final class AppColors {
  /// 主品牌色（紫）
  static const brand = Color(0xFF6C5CE7);

  /// 品牌漸層另一端（藍紫）
  static const brandAlt = Color(0xFF8E7BFF);

  /// 強調色（青）
  static const accent = Color(0xFF22D3EE);

  /// 成功
  static const success = Color(0xFF16A34A);

  /// 警告
  static const warning = Color(0xFFF59E0B);

  /// 危險
  static const danger = Color(0xFFEF4444);

  /// 區塊鏈／Web3 標籤色
  static const chain = Color(0xFF7C3AED);

  /// 品牌漸層
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brand, brandAlt],
  );
}

/// 隨主題變化的額外調色盤（不以 ColorScheme 表達的語意色）。
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brandGradient,
    required this.bubbleMe,
    required this.bubbleOther,
    required this.bubbleMeText,
    required this.bubbleOtherText,
    required this.cardBorder,
    required this.softSurface,
    required this.onSoftSurface,
    required this.successSurface,
    required this.dangerSurface,
    required this.shadow,
    required this.ring,
  });

  final LinearGradient brandGradient;
  final Color bubbleMe;
  final Color bubbleOther;
  final Color bubbleMeText;
  final Color bubbleOtherText;
  final Color cardBorder;
  final Color softSurface;
  final Color onSoftSurface;
  final Color successSurface;
  final Color dangerSurface;
  final Color shadow;
  final Color ring;

  static const light = AppPalette(
    brandGradient: AppColors.brandGradient,
    bubbleMe: Color(0xFF6C5CE7),
    bubbleOther: Color(0xFFFFFFFF),
    bubbleMeText: Color(0xFFFFFFFF),
    bubbleOtherText: Color(0xFF16181F),
    cardBorder: Color(0x14000000),
    softSurface: Color(0xFFF3F4FA),
    onSoftSurface: Color(0xFF4B5163),
    successSurface: Color(0xFFE8F7EE),
    dangerSurface: Color(0xFFFDECEC),
    shadow: Color(0x140F172A),
    ring: Color(0xFFE3E5EF),
  );

  static const dark = AppPalette(
    brandGradient: AppColors.brandGradient,
    bubbleMe: Color(0xFF6C5CE7),
    bubbleOther: Color(0xFF1C2130),
    bubbleMeText: Color(0xFFFFFFFF),
    bubbleOtherText: Color(0xFFEDEFF7),
    cardBorder: Color(0x1AFFFFFF),
    softSurface: Color(0xFF171B27),
    onSoftSurface: Color(0xFF9AA2B8),
    successSurface: Color(0xFF14291C),
    dangerSurface: Color(0xFF2C1719),
    shadow: Color(0x40000000),
    ring: Color(0xFF272C3A),
  );

  @override
  AppPalette copyWith({
    LinearGradient? brandGradient,
    Color? bubbleMe,
    Color? bubbleOther,
    Color? bubbleMeText,
    Color? bubbleOtherText,
    Color? cardBorder,
    Color? softSurface,
    Color? onSoftSurface,
    Color? successSurface,
    Color? dangerSurface,
    Color? shadow,
    Color? ring,
  }) {
    return AppPalette(
      brandGradient: brandGradient ?? this.brandGradient,
      bubbleMe: bubbleMe ?? this.bubbleMe,
      bubbleOther: bubbleOther ?? this.bubbleOther,
      bubbleMeText: bubbleMeText ?? this.bubbleMeText,
      bubbleOtherText: bubbleOtherText ?? this.bubbleOtherText,
      cardBorder: cardBorder ?? this.cardBorder,
      softSurface: softSurface ?? this.softSurface,
      onSoftSurface: onSoftSurface ?? this.onSoftSurface,
      successSurface: successSurface ?? this.successSurface,
      dangerSurface: dangerSurface ?? this.dangerSurface,
      shadow: shadow ?? this.shadow,
      ring: ring ?? this.ring,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      brandGradient: brandGradient,
      bubbleMe: Color.lerp(bubbleMe, other.bubbleMe, t)!,
      bubbleOther: Color.lerp(bubbleOther, other.bubbleOther, t)!,
      bubbleMeText: Color.lerp(bubbleMeText, other.bubbleMeText, t)!,
      bubbleOtherText: Color.lerp(bubbleOtherText, other.bubbleOtherText, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      softSurface: Color.lerp(softSurface, other.softSurface, t)!,
      onSoftSurface: Color.lerp(onSoftSurface, other.onSoftSurface, t)!,
      successSurface: Color.lerp(successSurface, other.successSurface, t)!,
      dangerSurface: Color.lerp(dangerSurface, other.dangerSurface, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      ring: Color.lerp(ring, other.ring, t)!,
    );
  }
}

/// 圓角與間距的統一尺度。
abstract final class AppRadius {
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 28.0;

  static const card = BorderRadius.all(Radius.circular(lg));
  static const sheet = BorderRadius.vertical(top: Radius.circular(xl));
}

abstract final class AppGap {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// 依據亮度建立主題。
abstract final class AppTheme {
  static ThemeData build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final seed = AppColors.brand;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    final textTheme = base.textTheme;

    final overlay = isDark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: const Color(0xFF0B0D14),
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.white,
          );

    return base.copyWith(
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF0B0D14) : const Color(0xFFF6F7FB),
      extensions: <ThemeExtension<dynamic>>[
        isDark ? AppPalette.dark : AppPalette.light,
      ],
      textTheme: textTheme.apply(
        bodyColor: isDark ? const Color(0xFFE9EBF5) : const Color(0xFF16181F),
        displayColor: isDark ? const Color(0xFFF4F5FA) : const Color(0xFF101320),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: overlay,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: isDark ? const Color(0xFFF4F5FA) : const Color(0xFF101320),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(
            color: isDark ? AppPalette.dark.cardBorder : AppPalette.light.cardBorder,
          ),
        ),
        color: isDark ? const Color(0xFF141821) : Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          side: BorderSide(
            color: isDark ? const Color(0xFF2A3040) : const Color(0xFFDCDFE9),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF171B27) : const Color(0xFFF2F3F9),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppGap.lg,
          vertical: AppGap.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.brand, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
        ),
        hintStyle: TextStyle(
          color: isDark ? const Color(0xFF7A8299) : const Color(0xFF9AA0B4),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? const Color(0xFF222736) : const Color(0xFFEBEDF4),
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: AppGap.lg),
        minVerticalPadding: 10,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF0F131C) : Colors.white,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isDark ? const Color(0xFF0F131C) : Colors.white,
        elevation: 0,
        groupAlignment: -0.9,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        selectedLabelTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      // 桌面瀏覽器預設的捲軸既粗又始終可見，跟整體調性不搭；
      // 這裡收細、改成半透明，滑過時才稍微加深。
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll<double>(9),
        radius: const Radius.circular(999),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          final hovered = states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.dragged);
          final base = isDark ? Colors.white : Colors.black;
          return base.withValues(alpha: hovered ? 0.32 : 0.15);
        }),
        trackColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
        trackBorderColor:
            const WidgetStatePropertyAll<Color>(Colors.transparent),
        crossAxisMargin: 3,
        mainAxisMargin: 4,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.brand,
        selectionColor: AppColors.brand.withValues(alpha: 0.25),
        selectionHandleColor: AppColors.brand,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
        backgroundColor: isDark ? const Color(0xFF141821) : Colors.white,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A3040) : const Color(0xFF1B1F2B),
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}

/// 方便取用 [AppPalette]。
extension AppPaletteX on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}

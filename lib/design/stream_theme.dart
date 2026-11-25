import 'package:flutter/material.dart';

import 'package:stream_ledger/design/stream_colors.dart';

/// 运行时调色板（代替原 Compose 的 LocalStreamColors）。
class StreamPalette extends ThemeExtension<StreamPalette> {
  final Color paperBase;
  final Color cardBackground;
  final Color textPrimary;
  final Color textSecondary;
  final Color hairline;
  final Color inputBackground;
  final Color accentWarmYellow;
  final Color textOnAccent;
  final Color accentPillBackground;
  final Color incomeGreen;
  final Color overBudgetRed;
  final Color fixedExpenseBlockColor;
  final Color deepSurface;
  final Color onDeep;
  final Color onDeepMuted;
  final bool isDark;

  const StreamPalette({
    required this.paperBase,
    required this.cardBackground,
    required this.textPrimary,
    required this.textSecondary,
    required this.hairline,
    required this.inputBackground,
    required this.accentWarmYellow,
    required this.textOnAccent,
    required this.accentPillBackground,
    required this.incomeGreen,
    required this.overBudgetRed,
    required this.fixedExpenseBlockColor,
    required this.deepSurface,
    required this.onDeep,
    required this.onDeepMuted,
    required this.isDark,
  });

  static StreamPalette get light => const StreamPalette(
        paperBase: StreamColors.lightPaperBase,
        cardBackground: StreamColors.lightCardBackground,
        textPrimary: StreamColors.lightTextPrimary,
        textSecondary: StreamColors.lightTextSecondary,
        hairline: StreamColors.lightHairline,
        inputBackground: StreamColors.lightInputBackground,
        accentWarmYellow: StreamColors.accentWarmYellow,
        textOnAccent: StreamColors.textOnAccent,
        accentPillBackground: StreamColors.accentPillBackground,
        incomeGreen: StreamColors.incomeGreen,
        overBudgetRed: StreamColors.overBudgetRed,
        fixedExpenseBlockColor: StreamColors.fixedExpenseBlockColor,
        deepSurface: StreamColors.deepSurface,
        onDeep: StreamColors.onDeep,
        onDeepMuted: StreamColors.onDeepMuted,
        isDark: false,
      );

  static StreamPalette get dark => const StreamPalette(
        paperBase: StreamColors.darkPaperBase,
        cardBackground: StreamColors.darkCardBackground,
        textPrimary: StreamColors.darkTextPrimary,
        textSecondary: StreamColors.darkTextSecondary,
        hairline: StreamColors.darkHairline,
        inputBackground: StreamColors.darkInputBackground,
        accentWarmYellow: StreamColors.accentWarmYellow,
        textOnAccent: StreamColors.textOnAccent,
        accentPillBackground: Color(0xFF2C2415),
        incomeGreen: StreamColors.darkIncomeGreen,
        overBudgetRed: StreamColors.overBudgetRed,
        fixedExpenseBlockColor: StreamColors.fixedExpenseBlockColor,
        deepSurface: StreamColors.deepSurfaceDark,
        onDeep: StreamColors.onDeep,
        onDeepMuted: StreamColors.onDeepMuted,
        isDark: true,
      );

  static StreamPalette of(BuildContext context) =>
      Theme.of(context).extension<StreamPalette>() ?? light;

  @override
  StreamPalette copyWith({
    Color? paperBase,
    Color? cardBackground,
    Color? textPrimary,
    Color? textSecondary,
    Color? hairline,
    Color? inputBackground,
    Color? accentWarmYellow,
    Color? textOnAccent,
    Color? accentPillBackground,
    Color? incomeGreen,
    Color? overBudgetRed,
    Color? fixedExpenseBlockColor,
    Color? deepSurface,
    Color? onDeep,
    Color? onDeepMuted,
    bool? isDark,
  }) {
    return StreamPalette(
      paperBase: paperBase ?? this.paperBase,
      cardBackground: cardBackground ?? this.cardBackground,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      hairline: hairline ?? this.hairline,
      inputBackground: inputBackground ?? this.inputBackground,
      accentWarmYellow: accentWarmYellow ?? this.accentWarmYellow,
      textOnAccent: textOnAccent ?? this.textOnAccent,
      accentPillBackground: accentPillBackground ?? this.accentPillBackground,
      incomeGreen: incomeGreen ?? this.incomeGreen,
      overBudgetRed: overBudgetRed ?? this.overBudgetRed,
      fixedExpenseBlockColor:
          fixedExpenseBlockColor ?? this.fixedExpenseBlockColor,
      deepSurface: deepSurface ?? this.deepSurface,
      onDeep: onDeep ?? this.onDeep,
      onDeepMuted: onDeepMuted ?? this.onDeepMuted,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  StreamPalette lerp(ThemeExtension<StreamPalette>? other, double t) {
    if (other is! StreamPalette) return this;
    return StreamPalette(
      paperBase: Color.lerp(paperBase, other.paperBase, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      inputBackground: Color.lerp(inputBackground, other.inputBackground, t)!,
      accentWarmYellow: Color.lerp(accentWarmYellow, other.accentWarmYellow, t)!,
      textOnAccent: Color.lerp(textOnAccent, other.textOnAccent, t)!,
      accentPillBackground:
          Color.lerp(accentPillBackground, other.accentPillBackground, t)!,
      incomeGreen: Color.lerp(incomeGreen, other.incomeGreen, t)!,
      overBudgetRed: Color.lerp(overBudgetRed, other.overBudgetRed, t)!,
      fixedExpenseBlockColor:
          Color.lerp(fixedExpenseBlockColor, other.fixedExpenseBlockColor, t)!,
      deepSurface: Color.lerp(deepSurface, other.deepSurface, t)!,
      onDeep: Color.lerp(onDeep, other.onDeep, t)!,
      onDeepMuted: Color.lerp(onDeepMuted, other.onDeepMuted, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

/// 应用主题：提供 StreamPalette 与 Material 3 基础色板。
class StreamTheme extends StatelessWidget {
  const StreamTheme({super.key, this.child, this.darkMode});

  final Widget? child;

  /// 为 null 时跟随系统亮度。
  final bool? darkMode;

  @override
  Widget build(BuildContext context) {
    final platformBrightness =
        MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light;
    final isDark = darkMode ?? platformBrightness == Brightness.dark;
    final palette = isDark ? StreamPalette.dark : StreamPalette.light;
    final brightness = isDark ? Brightness.dark : Brightness.light;

    final scheme = ColorScheme.fromSeed(
      seedColor: StreamColors.accentWarmYellow,
      brightness: brightness,
    ).copyWith(
      primary: palette.accentWarmYellow,
      onPrimary: palette.textOnAccent,
      surface: palette.cardBackground,
      onSurface: palette.textPrimary,
    );

    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: brightness,
        colorScheme: scheme,
        scaffoldBackgroundColor: palette.paperBase,
        extensions: <ThemeExtension<dynamic>>[palette],
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }
}
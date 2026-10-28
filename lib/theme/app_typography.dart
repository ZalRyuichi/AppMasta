import 'package:flutter/material.dart';

import 'app_theme.dart';

abstract final class AppTypography {
  static const fontFamily = 'Rajdhani';

  static TextStyle _base({
    required double size,
    FontWeight weight = FontWeight.w400,
    double? letterSpacing,
    double? height,
    Color? color,
    List<Shadow>? shadows,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
      shadows: shadows,
    );
  }

  static TextStyle brand({double size = 22, Color? color, Color? shadow}) {
    return _base(
      size: size,
      weight: FontWeight.w800,
      letterSpacing: 0.8,
      height: 1.1,
      color: color ?? AppColors.dashText,
      shadows: shadow != null ? [Shadow(color: shadow, offset: const Offset(2, 2), blurRadius: 0)] : null,
    );
  }

  static TextStyle brandLogo({double size = 28, Color? color, Color? shadow}) {
    return TextStyle(
      fontFamily: 'Genetic',
      fontSize: size,
      letterSpacing: size >= 28 ? 3 : 2,
      height: 1,
      fontWeight: FontWeight.w800,
      color: color ?? AppColors.dashText,
      shadows: shadow != null ? [Shadow(color: shadow, offset: const Offset(2, 2), blurRadius: 0)] : null,
    );
  }

  static TextStyle statValue({required bool active}) {
    return _base(
      size: 20,
      weight: FontWeight.w800,
      letterSpacing: 0.4,
      height: 1,
      color: active ? AppColors.dashAccent : AppColors.dashTextMuted,
    );
  }

  static TextStyle statLabel() {
    return _base(
      size: 10,
      weight: FontWeight.w700,
      letterSpacing: 1.0,
      color: AppColors.dashTextMuted,
    );
  }

  static TextStyle sectionTitle({bool light = true}) {
    return _base(
      size: 18,
      weight: FontWeight.w800,
      letterSpacing: 0.4,
      height: 1.2,
      color: light ? AppColors.dashText : AppColors.text,
    );
  }

  static TextStyle sectionSubtitle({bool light = true}) {
    return _base(
      size: 12,
      weight: FontWeight.w500,
      letterSpacing: 0.2,
      height: 1.4,
      color: light ? AppColors.dashTextMuted : AppColors.textMuted,
    );
  }

  static TextStyle menuTitle() {
    return _base(
      size: 15,
      weight: FontWeight.w800,
      letterSpacing: 0.2,
      height: 1.25,
      color: AppColors.dashText,
    );
  }

  static TextStyle menuSubtitle() {
    return _base(
      size: 13,
      weight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.45,
      color: AppColors.dashTextMuted,
    );
  }

  static TextStyle welcomeName() {
    return _base(
      size: 18,
      weight: FontWeight.w800,
      letterSpacing: 0.3,
      height: 1.2,
      color: AppColors.dashText,
    );
  }

  static TextStyle welcomeMeta() {
    return _base(
      size: 11,
      weight: FontWeight.w600,
      letterSpacing: 0.2,
      height: 1.3,
      color: AppColors.dashTextMuted,
    );
  }

  static TextStyle tagline({Color? color}) {
    return _base(
      size: 10,
      weight: FontWeight.w700,
      letterSpacing: 1.4,
      height: 1.2,
      color: color ?? AppColors.dashTextMuted,
    );
  }

  static TextStyle techId() {
    return _base(
      size: 10,
      weight: FontWeight.w600,
      letterSpacing: 0.2,
      height: 1.3,
      color: AppColors.dashText,
    );
  }

  static TextStyle fieldLabel() {
    return _base(
      size: 13,
      weight: FontWeight.w700,
      color: AppColors.dashText,
    );
  }

  static TextTheme apply(TextTheme base) {
    TextStyle map(TextStyle? style) => (style ?? const TextStyle()).copyWith(fontFamily: fontFamily);
    return TextTheme(
      displayLarge: map(base.displayLarge),
      displayMedium: map(base.displayMedium),
      displaySmall: map(base.displaySmall),
      headlineLarge: map(base.headlineLarge),
      headlineMedium: map(base.headlineMedium),
      headlineSmall: map(base.headlineSmall),
      titleLarge: map(base.titleLarge),
      titleMedium: map(base.titleMedium),
      titleSmall: map(base.titleSmall),
      bodyLarge: map(base.bodyLarge),
      bodyMedium: map(base.bodyMedium),
      bodySmall: map(base.bodySmall),
      labelLarge: map(base.labelLarge),
      labelMedium: map(base.labelMedium),
      labelSmall: map(base.labelSmall),
    ).apply(
      bodyColor: AppColors.dashText,
      displayColor: AppColors.dashText,
    );
  }
}

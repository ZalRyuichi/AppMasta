import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_typography.dart';

/// Neo-Brutalism color system — thick borders, hard shadows, high contrast.
class AppColors {
  // Dark (legacy / secondary)
  static const bg = Color(0xFF0A0A0A);
  static const card = Color(0xFF141414);
  static const cardElevated = Color(0xFF1C1C1C);
  static const accent = Color(0xFF00E676);
  static const accent2 = Color(0xFFFFE566);
  static const accent3 = Color(0xFF00C2FF);
  static const success = Color(0xFF00E676);
  static const error = Color(0xFF00C853);
  static const warning = Color(0xFFFFEA00);
  static const text = Color(0xFFF5F5F5);
  static const textMuted = Color(0xFF9E9E9E);
  static const border = Color(0xFF000000);

  // Neo-Brutal light (primary UI)
  static const dashBg = Color(0xFFFFFDF5); // warm paper
  static const dashSurface = Color(0xFFFFFFFF);
  static const dashAccent = Color(0xFF00E676); // hot pink
  static const dashAccent2 = Color(0xFFFFE566); // bold yellow
  static const dashAccentSoft = Color(0xFF8BFFA0);
  static const dashText = Color(0xFF0A0A0A);
  static const dashTextMuted = Color(0xFF5A5A5A);

  // Extra neo accents
  static const neoYellow = Color(0xFFFFE566);
  static const neoCyan = Color(0xFF00E5FF);
  static const neoLime = Color(0xFF76FF03);
  static const neoOrange = Color(0xFFFF6D00);
  static const neoPurple = Color(0xFFD500F9);
  static const neoBlack = Color(0xFF000000);
  static const neoWhite = Color(0xFFFFFFFF);
}

class AppRadius {
  // Neo-Brutal prefers sharp / mild radii
  static const sm = 4.0;
  static const md = 8.0;
  static const lg = 12.0;
  static const xl = 16.0;
}

class AppMotion {
  static const fast = Duration(milliseconds: 180);
  static const normal = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 420);
  static const curve = Curves.easeOutCubic;
  static const spring = Curves.easeOutBack;
}

/// Hard offset shadow helper (classic neo-brutal look)
class NeoShadow {
  static List<BoxShadow> hard({
    Color color = AppColors.neoBlack,
    double dx = 4,
    double dy = 4,
    double blur = 0,
  }) =>
      [
        BoxShadow(
          color: color,
          offset: Offset(dx, dy),
          blurRadius: blur,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> hardSm() => hard(dx: 3, dy: 3);
  static List<BoxShadow> hardMd() => hard(dx: 5, dy: 5);
  static List<BoxShadow> hardLg() => hard(dx: 6, dy: 6);
}

class NeoBorder {
  static Border all({Color color = AppColors.neoBlack, double width = 3}) =>
      Border.all(color: color, width: width);

  static BorderSide side({Color color = AppColors.neoBlack, double width = 3}) =>
      BorderSide(color: color, width: width);
}

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.accent2,
        surface: AppColors.card,
        error: AppColors.error,
      ),
      splashFactory: InkSparkle.splashFactory,
    );

    final textTheme = AppTypography.apply(base.textTheme).apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    );

    return base.copyWith(
      textTheme: textTheme,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.text,
        titleTextStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.5),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        hintStyle: TextStyle(fontFamily: AppTypography.fontFamily, color: AppColors.textMuted, fontSize: 14),
        labelStyle: TextStyle(fontFamily: AppTypography.fontFamily, color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: const BorderSide(color: AppColors.neoBlack, width: 2.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: const BorderSide(color: AppColors.neoBlack, width: 2.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: const BorderSide(color: AppColors.accent, width: 3)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: const BorderSide(color: AppColors.neoBlack, width: 2.5),
        ),
        backgroundColor: AppColors.cardElevated,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            side: const BorderSide(color: AppColors.neoBlack, width: 2.5),
          ),
        ),
      ),
    );
  }

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: AppColors.dashBg,
      colorScheme: const ColorScheme.light(
        primary: AppColors.dashAccent,
        secondary: AppColors.neoYellow,
        surface: AppColors.dashSurface,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSurface: AppColors.dashText,
      ),
      splashFactory: InkSparkle.splashFactory,
    );

    final textTheme = AppTypography.apply(base.textTheme).apply(
      bodyColor: AppColors.dashText,
      displayColor: AppColors.dashText,
    );

    return base.copyWith(
      textTheme: textTheme,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.dashSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.dashText,
        titleTextStyle: AppTypography.brand(size: 20).copyWith(color: AppColors.dashText, fontWeight: FontWeight.w800),
        shape: const Border(
          bottom: BorderSide(color: AppColors.neoBlack, width: 3),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: AppColors.dashSurface,
        indicatorColor: AppColors.dashAccent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: selected ? AppColors.dashText : AppColors.dashTextMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? Colors.white : AppColors.dashTextMuted,
            size: 22,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.dashSurface,
        hintStyle: TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 14, color: AppColors.dashTextMuted),
        labelStyle: TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.dashText),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.neoBlack, width: 2.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.neoBlack, width: 2.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.dashAccent, width: 3),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: const BorderSide(color: AppColors.neoBlack, width: 2.5),
        ),
        backgroundColor: AppColors.dashAccent,
        contentTextStyle: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          backgroundColor: AppColors.dashAccent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            side: const BorderSide(color: AppColors.neoBlack, width: 2.5),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.dashSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.neoBlack, width: 3),
        ),
        elevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.dashSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          side: BorderSide(color: AppColors.neoBlack, width: 3),
        ),
        elevation: 0,
      ),
    );
  }
}

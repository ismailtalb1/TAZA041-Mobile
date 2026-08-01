import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models.dart';

class TazaColors {
  static const Color darkBg = Color(0xFF0B0907);
  static const Color darkBg2 = Color(0xFF17110D);
  static const Color darkSurface = Color(0xFF271D16);
  static const Color darkCard = Color(0xFF19130F);
  static const Color textLight = Color(0xFFFFF4E8);
  static const Color mutedDark = Color(0xFFCBB9A3);
  static const Color accent = Color(0xFFFF8728);
  static const Color accent2 = Color(0xFFFFC45E);
  static const Color success = Color(0xFF16C784);
  static const Color danger = Color(0xFFFF5D73);
  static const Color warning = Color(0xFFF6B73C);
  static const Color info = Color(0xFF6FB7FF);

  static const Color lightBg = Color(0xFFF8F3EA);
  static const Color lightBg2 = Color(0xFFF3F7F1);
  static const Color lightSurface = Color(0xFFFFFCF6);
  static const Color textDark = Color(0xFF2B2118);
  static const Color mutedLight = Color(0xFF74685C);
}

class TazaThemes {
  static ThemeData dark(AppLanguage language) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: TazaColors.darkBg,
      colorScheme: const ColorScheme.dark(
        primary: TazaColors.accent,
        secondary: TazaColors.accent2,
        surface: TazaColors.darkSurface,
        error: TazaColors.danger,
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
    );
    final textTheme =
        _textTheme(base.textTheme, language, TazaColors.textLight);
    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: TazaColors.darkBg.withValues(alpha: .9),
        foregroundColor: TazaColors.textLight,
        elevation: 0,
        centerTitle: true,
        titleTextStyle:
            textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      cardColor: TazaColors.darkCard.withValues(alpha: .92),
      dividerColor: TazaColors.accent2.withValues(alpha: .17),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white.withValues(alpha: .06),
        selectedColor: TazaColors.accent.withValues(alpha: .18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        side: BorderSide(color: Colors.white.withValues(alpha: .08)),
      ),
      inputDecorationTheme:
          _inputDecoration(TazaColors.textLight, Colors.white12),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: TazaColors.accent,
          foregroundColor: const Color(0xFF211209),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: const StadiumBorder(),
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: TazaColors.textLight,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: Colors.white.withValues(alpha: .12)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: const StadiumBorder(),
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: TazaColors.darkBg2,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: TazaColors.darkSurface,
        contentTextStyle: textTheme.bodyMedium,
        behavior: SnackBarBehavior.floating,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: TazaColors.darkCard.withValues(alpha: .98),
        indicatorColor: TazaColors.accent.withValues(alpha: .22),
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
      ),
    );
  }

  static ThemeData light(AppLanguage language) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: TazaColors.lightBg,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFFD8741F),
        secondary: Color(0xFFF2B957),
        surface: TazaColors.lightSurface,
        error: Color(0xFFB54135),
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
    );
    final textTheme = _textTheme(base.textTheme, language, TazaColors.textDark);
    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: TazaColors.lightBg.withValues(alpha: .96),
        foregroundColor: TazaColors.textDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle:
            textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      cardColor: Colors.white.withValues(alpha: .94),
      dividerColor: TazaColors.textDark.withValues(alpha: .08),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white,
        selectedColor: TazaColors.accent.withValues(alpha: .12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        side: BorderSide(color: TazaColors.textDark.withValues(alpha: .08)),
      ),
      inputDecorationTheme: _inputDecoration(
          TazaColors.textDark, TazaColors.textDark.withValues(alpha: .1)),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD8741F),
          foregroundColor: const Color(0xFF211209),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: const StadiumBorder(),
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: TazaColors.textDark,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: TazaColors.textDark.withValues(alpha: .12)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: const StadiumBorder(),
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: TazaColors.lightBg2,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Colors.white,
        contentTextStyle: textTheme.bodyMedium,
        behavior: SnackBarBehavior.floating,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: Colors.white.withValues(alpha: .98),
        indicatorColor: const Color(0xFFD8741F).withValues(alpha: .16),
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
      ),
    );
  }

  static TextTheme _textTheme(
      TextTheme base, AppLanguage language, Color color) {
    final themed = language == AppLanguage.ar
        ? GoogleFonts.ibmPlexSansArabicTextTheme(base)
        : GoogleFonts.manropeTextTheme(base);
    return themed.apply(bodyColor: color, displayColor: color);
  }

  static InputDecorationTheme _inputDecoration(
      Color textColor, Color borderColor) {
    return InputDecorationTheme(
      filled: true,
      fillColor: Colors.white
          .withValues(alpha: textColor == TazaColors.textLight ? .04 : .8),
      hintStyle: TextStyle(color: textColor.withValues(alpha: .55)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        borderSide: BorderSide(color: TazaColors.accent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      constraints: const BoxConstraints(minHeight: 56),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The colours of NF Hotel: a dark navy with an amber accent on a light,
/// card-based layout.
abstract final class AppColors {
  static const Color navy = Color(0xFF16233F);
  static const Color navyDark = Color(0xFF0B1220);
  static const Color amber = Color(0xFFF2A73B);
  static const Color background = Color(0xFFF3F5F8);
  static const Color text = Color(0xFF334155);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color border = Color(0xFFE2E8F0);
  static const Color clean = Color(0xFF16A34A);
  static const Color error = Color(0xFFB91C1C);
}

/// The theme of the app: Playfair Display for the headings, Inter for the rest.
///
/// Only the weights in `assets/google_fonts` are asked for (Playfair Display
/// 600 and 700, Inter 400 and 600), because the app does not fetch fonts at run
/// time and a missing weight fails to load.
ThemeData buildAppTheme() {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
  final text = base.textTheme;

  TextStyle serif(TextStyle? style, FontWeight weight) =>
      GoogleFonts.playfairDisplay(
        textStyle: style,
        fontWeight: weight,
        color: AppColors.navyDark,
      );

  TextStyle sans(
    TextStyle? style, {
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.textMuted,
    double? letterSpacing,
  }) => GoogleFonts.inter(
    textStyle: style,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
  );

  final buttonText = sans(null, weight: FontWeight.w600, color: Colors.white);
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(8),
  );
  final filledButton = FilledButton.styleFrom(
    backgroundColor: AppColors.navy,
    foregroundColor: Colors.white,
    disabledBackgroundColor: AppColors.navy.withValues(alpha: 0.4),
    disabledForegroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
    textStyle: buttonText,
    shape: buttonShape,
    elevation: 0,
  );
  final roundedField = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AppColors.border),
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.navy,
      secondary: AppColors.amber,
      surface: Colors.white,
      error: AppColors.error,
    ),
    textTheme: text.copyWith(
      displayLarge: serif(text.displayLarge, FontWeight.w700),
      displayMedium: serif(text.displayMedium, FontWeight.w700),
      displaySmall: serif(text.displaySmall, FontWeight.w700),
      headlineLarge: serif(text.headlineLarge, FontWeight.w700),
      headlineMedium: serif(text.headlineMedium, FontWeight.w700),
      headlineSmall: serif(text.headlineSmall, FontWeight.w700),
      titleLarge: serif(text.titleLarge, FontWeight.w700),
      titleMedium: serif(text.titleMedium, FontWeight.w600),
      titleSmall: sans(
        text.titleSmall,
        weight: FontWeight.w600,
        color: AppColors.navyDark,
      ),
      bodyLarge: sans(text.bodyLarge, color: AppColors.text),
      bodyMedium: sans(text.bodyMedium),
      bodySmall: sans(text.bodySmall),
      labelLarge: sans(
        text.labelLarge,
        weight: FontWeight.w600,
        color: AppColors.navyDark,
        letterSpacing: 0.4,
      ),
      labelMedium: sans(text.labelMedium, weight: FontWeight.w600),
      labelSmall: sans(text.labelSmall, weight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.navyDark,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: serif(null, FontWeight.w700).copyWith(fontSize: 20),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    filledButtonTheme: FilledButtonThemeData(style: filledButton),
    elevatedButtonTheme: ElevatedButtonThemeData(style: filledButton),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.navy,
        side: const BorderSide(color: AppColors.navy),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: buttonText,
        shape: buttonShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.navy,
        textStyle: buttonText,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: roundedField,
      enabledBorder: roundedField,
      focusedBorder: roundedField.copyWith(
        borderSide: const BorderSide(color: AppColors.navy, width: 2),
      ),
      labelStyle: sans(null, weight: FontWeight.w600),
    ),
    checkboxTheme: CheckboxThemeData(
      // A locked box stays faint, so that it does not look as if it can be
      // tapped.
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (!states.contains(WidgetState.selected)) {
          return Colors.transparent;
        }
        return states.contains(WidgetState.disabled)
            ? AppColors.navy.withValues(alpha: 0.38)
            : AppColors.navy;
      }),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    listTileTheme: ListTileThemeData(
      selectedTileColor: AppColors.navy.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.navy,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border),
  );
}

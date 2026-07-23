import 'package:flutter/material.dart';

import '../design/app_colors.dart';

ThemeData buildAppTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.navy,
    onPrimary: Colors.white,
    secondary: AppColors.blue,
    onSecondary: Colors.white,
    tertiary: AppColors.teal,
    error: AppColors.red,
    surface: AppColors.card,
    onSurface: AppColors.textPrimary,
    outline: AppColors.border,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Inter',
    fontFamilyFallback: const <String>[
      'Noto Sans JP',
      'Noto Sans CJK JP',
      'sans-serif',
    ],
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
      iconTheme: IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.navy,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        side: const BorderSide(color: AppColors.navy),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.blue, width: 2)),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
  );
}


ThemeData buildDarkAppTheme() {
  final base = buildAppTheme();
  const scheme = ColorScheme.dark(
    primary: Color(0xFF8EB9FF),
    onPrimary: Color(0xFF08234A),
    secondary: Color(0xFF8EB9FF),
    onSecondary: Color(0xFF08234A),
    tertiary: Color(0xFF75D6C4),
    error: Color(0xFFFFB4AB),
    surface: Color(0xFF172033),
    onSurface: Color(0xFFF4F6FA),
    outline: Color(0xFF42506A),
  );
  final darkTextTheme = base.textTheme.apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );
  return base.copyWith(
    brightness: Brightness.dark,
    colorScheme: scheme,
    textTheme: darkTextTheme,
    primaryTextTheme: darkTextTheme,
    iconTheme: const IconThemeData(color: Color(0xFFF4F6FA)),
    listTileTheme: const ListTileThemeData(
      textColor: Color(0xFFF4F6FA),
      iconColor: Color(0xFFD7E2F5),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Color(0xFF172033),
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: Color(0xFFF4F6FA),
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: TextStyle(
        color: Color(0xFFD7E2F5),
        fontSize: 14,
        height: 1.5,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF172033),
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: Color(0xFF172033),
    ),
    scaffoldBackgroundColor: const Color(0xFF0E1524),
    cardTheme: base.cardTheme.copyWith(
      color: const Color(0xFF172033),
      shadowColor: Colors.black.withValues(alpha: 0.24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF42506A)),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF42506A),
      thickness: 1,
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      fillColor: const Color(0xFF172033),
    ),
  );
}

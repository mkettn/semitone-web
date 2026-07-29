import 'package:flutter/material.dart';

/// Colour palette ported from the original Semitone Android app
/// (src/main/res/values/colors.xml).
class SemitoneColors {
  SemitoneColors._();

  static const black = Color(0xFF181818);
  static const grey1 = Color(0xFF282828);
  static const grey2 = Color(0xFF383838);
  static const grey3 = Color(0xFF585858);
  static const grey4 = Color(0xFFB8B8B8);
  static const white = Color(0xFFD8D8D8);
  static const blue = Color(0xFF7CAFC2);
  static const red = Color(0xFFAB4642);
}

ThemeData buildSemitoneTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: SemitoneColors.blue,
    brightness: Brightness.dark,
    surface: SemitoneColors.black,
    primary: SemitoneColors.blue,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: SemitoneColors.black,
    appBarTheme: const AppBarTheme(
      backgroundColor: SemitoneColors.black,
      foregroundColor: SemitoneColors.white,
      elevation: 0,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: SemitoneColors.blue,
      unselectedLabelColor: SemitoneColors.grey4,
      indicatorColor: SemitoneColors.blue,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: SemitoneColors.white),
      bodyLarge: TextStyle(color: SemitoneColors.white),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: SemitoneColors.white,
      iconColor: SemitoneColors.grey4,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? SemitoneColors.blue
            : SemitoneColors.grey4,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? SemitoneColors.blue.withValues(alpha: 0.5)
            : SemitoneColors.grey2,
      ),
    ),
    cardTheme: const CardThemeData(
      color: SemitoneColors.grey1,
      elevation: 0,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: SemitoneColors.grey1,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: SemitoneColors.grey2,
      border: OutlineInputBorder(borderSide: BorderSide.none),
    ),
    dividerTheme: const DividerThemeData(color: SemitoneColors.grey2),
    iconTheme: const IconThemeData(color: SemitoneColors.grey4),
  );
}

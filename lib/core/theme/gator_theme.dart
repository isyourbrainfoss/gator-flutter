import 'package:flutter/material.dart';

/// Material 3 themes for Gator, using Adwaita-inspired palettes from the GTK app.
abstract final class GatorTheme {
  // Light palette
  static const _lightPrimary = Color(0xFF3584E4);
  static const _lightOnPrimary = Color(0xFFFFFFFF);
  static const _lightSurface = Color(0xFFFAFAFA);
  static const _lightSurfaceContainerHighest = Color(0xFFE0E0E0);
  static const _lightOutline = Color(0xFFC0C0C0);
  static const _lightError = Color(0xFFE01B24);

  // Dark palette
  static const _darkPrimary = Color(0xFF78AEED);
  static const _darkOnPrimary = Color(0xFF1E1E1E);
  static const _darkSurface = Color(0xFF242424);
  static const _darkSurfaceContainerHighest = Color(0xFF3D3D3D);
  static const _darkOutline = Color(0xFF5E5E5E);
  static const _darkError = Color(0xFFFF6B6B);

  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: _lightPrimary,
      onPrimary: _lightOnPrimary,
      primaryContainer: Color(0xFFD4E4F9),
      onPrimaryContainer: Color(0xFF0D3B6E),
      secondary: Color(0xFF5E5C71),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFE4E1EC),
      onSecondaryContainer: Color(0xFF1B1B23),
      tertiary: Color(0xFF7D5260),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFFFD8E4),
      onTertiaryContainer: Color(0xFF31111D),
      error: _lightError,
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      surface: _lightSurface,
      onSurface: Color(0xFF1E1E1E),
      surfaceContainerHighest: _lightSurfaceContainerHighest,
      surfaceContainerHigh: Color(0xFFE8E8E8),
      surfaceContainer: Color(0xFFF0F0F0),
      surfaceContainerLow: Color(0xFFF5F5F5),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      onSurfaceVariant: Color(0xFF5E5E5E),
      outline: _lightOutline,
      outlineVariant: Color(0xFFD6D6D6),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFF303030),
      onInverseSurface: Color(0xFFF5F5F5),
      inversePrimary: _darkPrimary,
      surfaceTint: _lightPrimary,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: _lightSurface,
        foregroundColor: Color(0xFF1E1E1E),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: _lightSurfaceContainerHighest,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E1E1E),
            );
          }
          return const TextStyle(fontSize: 12, color: Color(0xFF5E5E5E));
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _lightPrimary);
          }
          return const IconThemeData(color: Color(0xFF5E5E5E));
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _lightPrimary,
          foregroundColor: _lightOnPrimary,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Color(0xFF1E1E1E),
          side: const BorderSide(color: _lightOutline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: _lightOutline),
          borderRadius: BorderRadius.circular(6),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: _lightOutline),
          borderRadius: BorderRadius.circular(6),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: _lightPrimary, width: 2),
          borderRadius: BorderRadius.circular(6),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: _lightError),
          borderRadius: BorderRadius.circular(6),
        ),
        filled: true,
        fillColor: Color(0xFFFFFFFF),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: Color(0xFFF5F5F5),
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  static ThemeData dark() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: _darkPrimary,
      onPrimary: _darkOnPrimary,
      primaryContainer: Color(0xFF1B3F6B),
      onPrimaryContainer: Color(0xFFD4E4F9),
      secondary: Color(0xFFC4C6D0),
      onSecondary: Color(0xFF2E2F38),
      secondaryContainer: Color(0xFF3D3D3D),
      onSecondaryContainer: Color(0xFFE0E0E0),
      tertiary: Color(0xFFEFB8C8),
      onTertiary: Color(0xFF492532),
      tertiaryContainer: Color(0xFF633B48),
      onTertiaryContainer: Color(0xFFFFD8E4),
      error: _darkError,
      onError: Color(0xFF1E1E1E),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: _darkSurface,
      onSurface: Color(0xFFE0E0E0),
      surfaceContainerHighest: _darkSurfaceContainerHighest,
      surfaceContainerHigh: Color(0xFF383838),
      surfaceContainer: Color(0xFF333333),
      surfaceContainerLow: Color(0xFF2E2E2E),
      surfaceContainerLowest: Color(0xFF1E1E1E),
      onSurfaceVariant: Color(0xFFC0C0C0),
      outline: _darkOutline,
      outlineVariant: Color(0xFF3D3D3D),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFFE0E0E0),
      onInverseSurface: Color(0xFF1E1E1E),
      inversePrimary: _lightPrimary,
      surfaceTint: _darkPrimary,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkSurface,
        foregroundColor: Color(0xFFE0E0E0),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: _darkSurfaceContainerHighest,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE0E0E0),
            );
          }
          return const TextStyle(fontSize: 12, color: Color(0xFFC0C0C0));
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _darkPrimary);
          }
          return const IconThemeData(color: Color(0xFFC0C0C0));
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _darkPrimary,
          foregroundColor: _darkOnPrimary,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Color(0xFFE0E0E0),
          side: const BorderSide(color: _darkOutline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: _darkOutline),
          borderRadius: BorderRadius.circular(6),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: _darkOutline),
          borderRadius: BorderRadius.circular(6),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: _darkPrimary, width: 2),
          borderRadius: BorderRadius.circular(6),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: _darkError),
          borderRadius: BorderRadius.circular(6),
        ),
        filled: true,
        fillColor: Color(0xFF2E2E2E),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: Color(0xFF2E2E2E),
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
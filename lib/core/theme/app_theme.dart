import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class AppTheme {
  // Brand colors from the ScanFlow design system
  static const Color lightPrimary = Color(0xFF2563EB);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightPrimaryContainer = Color(0xFFDBEAFE);
  static const Color lightOnPrimaryContainer = Color(0xFF0F172A);

  static const Color lightSecondary = Color(0xFF475569);
  static const Color lightOnSecondary = Color(0xFFFFFFFF);
  static const Color lightSecondaryContainer = Color(0xFFE2E8F0);
  static const Color lightOnSecondaryContainer = Color(0xFF0F172A);

  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightOnSurface = Color(0xFF0F172A);
  static const Color lightSurfaceContainerHighest = Color(0xFFF8FAFC);
  static const Color lightOnSurfaceVariant = Color(0xFF475569);

  static const Color lightOutline = Color(0xFFCBD5E1);
  static const Color lightError = Color(0xFFEF4444);
  static const Color lightSuccess = Color(0xFF22C55E);
  static const Color lightWarning = Color(0xFFF59E0B);

  // Dark theme colors from the design system
  static const Color darkPrimary = Color(0xFF60A5FA);
  static const Color darkOnPrimary = Color(0xFF0F172A);
  static const Color darkPrimaryContainer = Color(0xFF1E3A8A);
  static const Color darkOnPrimaryContainer = Color(0xFFEFF6FF);

  static const Color darkSecondary = Color(0xFFCBD5E1);
  static const Color darkOnSecondary = Color(0xFF0F172A);
  static const Color darkSecondaryContainer = Color(0xFF334155);
  static const Color darkOnSecondaryContainer = Color(0xFFF8FAFC);

  static const Color darkSurface = Color(0xFF0F172A);
  static const Color darkOnSurface = Color(0xFFF8FAFC);
  static const Color darkSurfaceContainerHighest = Color(0xFF1E293B);
  static const Color darkOnSurfaceVariant = Color(0xFFCBD5E1);

  static const Color darkOutline = Color(0xFF334155);
  static const Color darkError = Color(0xFFF87171);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: lightPrimary,
        onPrimary: lightOnPrimary,
        primaryContainer: lightPrimaryContainer,
        onPrimaryContainer: lightOnPrimaryContainer,
        secondary: lightSecondary,
        onSecondary: lightOnSecondary,
        secondaryContainer: lightSecondaryContainer,
        onSecondaryContainer: lightOnSecondaryContainer,
        error: lightError,
        onError: Colors.white,
        surface: lightSurface,
        onSurface: lightOnSurface,
        surfaceContainerHighest: lightSurfaceContainerHighest,
        onSurfaceVariant: lightOnSurfaceVariant,
        outline: lightOutline,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurface,
        foregroundColor: lightOnSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: lightOnSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 1,
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          side: BorderSide(
            color: lightOutline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightPrimary,
          foregroundColor: lightOnPrimary,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusL),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          borderSide: BorderSide(color: lightOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          borderSide: BorderSide(color: lightOutline.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          borderSide: const BorderSide(color: lightPrimary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: darkPrimary,
        onPrimary: darkOnPrimary,
        primaryContainer: darkPrimaryContainer,
        onPrimaryContainer: darkOnPrimaryContainer,
        secondary: darkSecondary,
        onSecondary: darkOnSecondary,
        secondaryContainer: darkSecondaryContainer,
        onSecondaryContainer: darkOnSecondaryContainer,
        error: darkError,
        onError: Colors.black,
        surface: darkSurface,
        onSurface: darkOnSurface,
        surfaceContainerHighest: darkSurfaceContainerHighest,
        onSurfaceVariant: darkOnSurfaceVariant,
        outline: darkOutline,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkOnSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: darkOnSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 1,
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          side: BorderSide(
            color: darkOutline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: darkOnPrimary,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusL),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          borderSide: BorderSide(color: darkOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          borderSide: BorderSide(color: darkOutline.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          borderSide: const BorderSide(color: darkPrimary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

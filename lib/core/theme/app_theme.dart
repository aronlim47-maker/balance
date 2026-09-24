import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _seed = Color(0xFF385844);
  static const surface = Color(0xFFF7F5EF);

  static ThemeData get light {
    final colors = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
      surface: surface,
    );

    return ThemeData(
      colorScheme: colors,
      scaffoldBackgroundColor: surface,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE7E3D9)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

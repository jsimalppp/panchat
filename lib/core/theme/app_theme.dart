import 'package:flutter/material.dart';

/// Panda identity: bamboo green + panda black/white. Not WhatsApp's look.
class PandaColors {
  static const bamboo = Color(0xFF2F9E5E);
  static const bambooDark = Color(0xFF1F7A45);
  static const bambooSoft = Color(0xFFE4F5EA);
  static const ink = Color(0xFF16221B);
  static const mist = Color(0xFFF6FAF7);
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: PandaColors.bamboo,
      brightness: Brightness.light,
    ).copyWith(primary: PandaColors.bamboo, surface: Colors.white);
    return _base(scheme, PandaColors.mist);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: PandaColors.bamboo,
      brightness: Brightness.dark,
    );
    return _base(scheme, const Color(0xFF0F1712));
  }

  static ThemeData _base(ColorScheme scheme, Color bg) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.brightness == Brightness.light
            ? PandaColors.bamboo
            : scheme.surface,
        foregroundColor: scheme.brightness == Brightness.light
            ? Colors.white
            : scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: PandaColors.bamboo,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: PandaColors.bamboo,
          minimumSize: const Size.fromHeight(50),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

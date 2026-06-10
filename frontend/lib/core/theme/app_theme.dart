import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Heritage-inspired theme for HeritageAR.
class AppTheme {
  AppTheme._();

  // ─── Unified heritage palette ─────────────────────────────────────────────
  static const Color primary   = Color(0xFF8B5E3C); // warm terracotta brown
  static const Color secondary = Color(0xFFD4A017); // heritage gold
  static const Color surface   = Color(0xFFF8F3EC); // warm parchment
  static const Color textBase  = Color(0xFF2D1B0E); // deep espresso
  static const Color darkBg    = Color(0xFF1A0A00); // deep cocoa

  // ── Light Theme ───────────────────────────────────────────────────────────
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          secondary: secondary,
          surface: surface,
        ),
        scaffoldBackgroundColor: surface,
        appBarTheme: const AppBarTheme(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        textTheme: const TextTheme(
          displaySmall: TextStyle(
              fontFamily: 'Georgia',
              color: textBase,
              fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(
              fontFamily: 'Georgia',
              color: textBase,
              fontWeight: FontWeight.bold),
          headlineSmall:
              TextStyle(fontFamily: 'Georgia', color: textBase),
          titleLarge: TextStyle(
              color: textBase,
              fontWeight: FontWeight.w700,
              fontSize: 18),
          bodyMedium: TextStyle(color: Color(0xFF4E342E), height: 1.55),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            side: const BorderSide(color: primary),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: secondary,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      );

  // ── Dark Theme ────────────────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF120800),
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          secondary: secondary,
          brightness: Brightness.dark,
        ),
        textTheme: const TextTheme(
          displaySmall: TextStyle(
              fontFamily: 'Georgia',
              color: Colors.white,
              fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(
              fontFamily: 'Georgia',
              color: Colors.white,
              fontWeight: FontWeight.bold),
          titleLarge: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
          bodyMedium: TextStyle(color: Color(0xFFD7CCC8), height: 1.55),
        ),
      );
}

// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // llama_cpp_dart needs no global initialization — nothing to call here.
  // (FlutterGemma.initialize() has been removed.)

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const SigiriyaApp());
}

class SigiriyaApp extends StatelessWidget {
  const SigiriyaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sigiriya Heritage',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const SplashScreen(),
    );
  }

  ThemeData _buildTheme() {
    const gold = Color(0xFFD4A017);
    const darkBrown = Color(0xFF1A0E00);
    const deepBrown = Color(0xFF2C1A0E);
    const lightCream = Color(0xFFFDF6E3);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: gold,
        secondary: const Color(0xFFB8860B),
        surface: deepBrown,
        background: darkBrown,
        onPrimary: darkBrown,
        onSecondary: lightCream,
        onSurface: lightCream,
        onBackground: lightCream,
        tertiary: const Color(0xFF8B4513),
      ),
      scaffoldBackgroundColor: darkBrown,
      appBarTheme: const AppBarTheme(
        backgroundColor: deepBrown,
        foregroundColor: gold,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: deepBrown,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF5C3D1E), width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF3A2410),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF5C3D1E)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF5C3D1E)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: gold, width: 2),
        ),
        hintStyle: TextStyle(color: lightCream.withOpacity(0.35)),
        prefixIconColor: gold,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: gold,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
        titleLarge: TextStyle(
          color: gold,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: lightCream,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(color: lightCream, fontSize: 15, height: 1.6),
        bodyMedium: TextStyle(color: lightCream, fontSize: 14, height: 1.5),
        labelLarge: TextStyle(
          color: darkBrown,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: darkBrown,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF3A2410),
        selectedColor: gold,
        labelStyle: const TextStyle(color: lightCream, fontSize: 12),
        side: const BorderSide(color: Color(0xFF5C3D1E)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: deepBrown,
        selectedItemColor: gold,
        unselectedItemColor: Colors.white38,
      ),
    );
  }
}

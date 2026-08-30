import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';
import 'features/sigiriya_guide/screens/splash_screen.dart' as sigiriya_guide;
import 'features/translation/engine/offline_translation_engine.dart';

// ML Kit's on-device translation models only support these — Sinhala isn't
// among them and always falls back to the offline heritage dictionary.
const _mlKitTargetLanguages = ['hi', 'ta', 'zh', 'es', 'fr', 'de'];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HeritageArApp());

  // Fire-and-forget: warm up every ML Kit offline language pack right when
  // the app launches, instead of waiting for the AR translator screen to
  // trigger a ~25-30MB download on first use of each language. Runs after
  // runApp so it never blocks the first frame; MlKitTranslationService.
  // statusStream lets any screen show live, per-language download progress.
  unawaited(
    OfflineTranslationEngine.instance
        .preloadAllOfflineModels(_mlKitTargetLanguages),
  );
}

/// Optional bootstrap for the imported Sigiriya guide app.
///
/// This keeps the existing HeritageAR app as the default launch path while
/// still making the Sigiriya standalone entrypoint available from the real
/// `lib/main.dart` file.
Future<void> runSigiriyaGuideApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const SigiriyaGuideApp());
}

class HeritageArApp extends StatelessWidget {
  const HeritageArApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HeritageAR',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}

class SigiriyaGuideApp extends StatelessWidget {
  const SigiriyaGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sigiriya Heritage',
      debugShowCheckedModeBanner: false,
      theme: _buildSigiriyaTheme(),
      home: const sigiriya_guide.SplashScreen(),
    );
  }

  ThemeData _buildSigiriyaTheme() {
    const gold = Color(0xFFD4A017);
    const darkBrown = Color(0xFF1A0E00);
    const deepBrown = Color(0xFF2C1A0E);
    const lightCream = Color(0xFFFDF6E3);

    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: gold,
        secondary: Color(0xFFB8860B),
        surface: deepBrown,
        onPrimary: darkBrown,
        onSecondary: lightCream,
        onSurface: lightCream,
        tertiary: Color(0xFF8B4513),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

import 'features/emergency_dashboard/presentation/screens/startup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait orientation
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Enable 90-120Hz high refresh rate on supported devices
  try {
    await FlutterDisplayMode.setHighRefreshRate();
  } catch (e) {
    // Ignore on devices that don't support it
  }

  runApp(const ProviderScope(child: KreoAssistApp()));
}

class KreoAssistApp extends StatelessWidget {
  const KreoAssistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KreoAssist',
      debugShowCheckedModeBanner: false,
      theme: _buildPitchBlackTheme(),
      darkTheme: _buildPitchBlackTheme(),
      themeMode: ThemeMode.dark,
      home: const StartupScreen(),
    );
  }

  ThemeData _buildPitchBlackTheme() {
    // Premium font setup - Inter for body, Outfit for headings
    final textTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      // Apply premium fonts
      textTheme: textTheme.copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        displayMedium: GoogleFonts.outfit(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        headlineLarge: GoogleFonts.outfit(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Colors.white,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Colors.white,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFF6B35),
        secondary: Color(0xFFFF8C42),
        tertiary: Color(0xFFFFAB40),
        surface: Colors.black,
        error: Color(0xFFFF5252),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
        onError: Colors.white,
      ),
      useMaterial3: true,
      cardTheme: const CardThemeData(
        color: Color(0xFF0D0D0D),
        elevation: 0,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.black,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFF121212),
      ),
    );
  }
}

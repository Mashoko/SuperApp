import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WunzaColors {
  // --- Glide brand (Super App) ---
  static const Color glidePrimary = Color(0xFF4A148C); // Deep Purple
  static const Color glideAccent = Color(0xFFFF6D00); // Vibrant Orange
  static const Color glideNeutral = Color(0xFFF5F5F7); // Light Gray

  // --- Existing Colors (Preserved for compatibility) ---
  static const Color primary = Color(0xFF00897B); // Original Teal
  static const Color secondary = Color(0xFF3E3E3E); // Dark Grey
  static const Color background = Color(0xFFF5F5F5); // Light Grey
  static const Color surface = Colors.white;
  static const Color error = Color(0xFFD32F2F);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color divider = Color(0xFFBDBDBD);
  static const Color success = Color(0xFF388E3C);

  // --- Premium Grey Palette ---
  static const Color premiumGrey = Color(0xFFF5F5F7);
  static const Color premiumSurface = Color(0xFFFFFFFF);
  static const Color premiumText = Color(0xFF1D1D1F);

  // --- NEW: Modern Palette (Added) ---
  static const Color indigo = Color(0xFF4F46E5);
  static const Color blueAccent = Color(0xFF3B82F6);
  static const Color orangeAccent = Color(0xFFF59E0B);
  static const Color greenAccent = Color(0xFF10B981);
  
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // --- Glass bottom nav tokens (nav-scoped only; phase 2 folds these
  // into the app-wide ColorScheme) ---
  static const Color navBgDark = Color(0xFF0B0B0E);
  static const Color navBgLight = Color(0xFFF2F1EE);
  static const Color navGlassDark = Color(0x801E1E24); // rgba(30,30,36,0.5)
  static const Color navGlassLight = Color(0x8CFFFFFF); // rgba(255,255,255,0.55)
  static const Color navIndicator = Color(0xFF9B8CFF); // violet, active-tab glow only
  static const Color padGradientStart = Color(0xFFFF7A45); // coral
  static const Color padGradientEnd = Color(0xFFFF4D6D); // pink
}

class WunzaTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: WunzaColors.glidePrimary,
        primary: const Color(0xFFCE93D8),   // light purple on dark
        secondary: WunzaColors.glideAccent,
        surface: const Color(0xFF1E1E2E),
        error: WunzaColors.error,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF12121C),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardColor: const Color(0xFF1E1E2E),
      dividerColor: Colors.white12,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFCE93D8),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFCE93D8),
          side: const BorderSide(color: Color(0xFFCE93D8)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
        displayMedium: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
        headlineLarge: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        headlineMedium: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        headlineSmall: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        titleLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
        bodyLarge: GoogleFonts.inter(fontSize: 16, color: Colors.white),
        bodyMedium: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
        bodySmall: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
        labelMedium: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white54),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2A2A3E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCE93D8), width: 2),
        ),
        hintStyle: const TextStyle(color: Colors.white38),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      bottomAppBarTheme: const BottomAppBarThemeData(
        color: Color(0xFF1E1E2E),
        elevation: 12,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? const Color(0xFFCE93D8)
              : Colors.white38,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? const Color(0xFFCE93D8).withValues(alpha: 0.4)
              : Colors.white12,
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      
      // Glide: Deep Purple primary, Vibrant Orange secondary/accent
        colorScheme: ColorScheme.fromSeed(
          seedColor: WunzaColors.glidePrimary,
          primary: WunzaColors.glidePrimary,
          secondary: WunzaColors.glideAccent,
          surface: WunzaColors.surface,
          error: WunzaColors.error,
        ),
      
      scaffoldBackgroundColor: WunzaColors.glideNeutral,
      
      // 2. Modern Transparent App Bar
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: WunzaColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),

      // 3. Preserved Button Styling (Critical for forms)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: WunzaColors.glidePrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), // Slightly more rounded
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: WunzaColors.glidePrimary,
          side: const BorderSide(color: WunzaColors.glidePrimary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),

      // Section headers: bold; card titles: medium; subtitles: lighter gray
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: WunzaColors.textPrimary,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: WunzaColors.textPrimary,
        ),
        displaySmall: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: WunzaColors.textPrimary,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: WunzaColors.textPrimary,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: WunzaColors.textPrimary,
        ),
        headlineSmall: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: WunzaColors.textPrimary,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: WunzaColors.textPrimary,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: WunzaColors.textPrimary,
        ),
        titleSmall: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: WunzaColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          color: WunzaColors.textPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          color: WunzaColors.textPrimary,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          color: WunzaColors.textSecondary,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: WunzaColors.textSecondary,
        ),
      ),

      // 5. Preserved Input Decoration (Critical for Login/Signup)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WunzaColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), // Updated radius
          borderSide: const BorderSide(color: WunzaColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: WunzaColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: WunzaColors.glidePrimary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WunzaColors {
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
}

class WunzaTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      
      // 1. Updated Color Scheme to Indigo (Modern Look)
        colorScheme: ColorScheme.fromSeed(
          seedColor: WunzaColors.indigo,
          primary: WunzaColors.indigo,
          secondary: WunzaColors.secondary,
          surface: WunzaColors.surface,
          error: WunzaColors.error,
        ),
      
      scaffoldBackgroundColor: WunzaColors.background,
      
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
          backgroundColor: WunzaColors.indigo, // Updated to use new primary
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
          foregroundColor: WunzaColors.indigo,
          side: const BorderSide(color: WunzaColors.indigo),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),

      // 4. Preserved Text Styling
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
        headlineMedium: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: WunzaColors.textPrimary,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
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
          borderSide: const BorderSide(color: WunzaColors.indigo, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
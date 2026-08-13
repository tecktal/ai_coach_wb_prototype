import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Design Tokens - Palette (Stitch Design)
  static const Color primaryColor = Color(0xFF14B8A5); // Teal
  static const Color primaryDark = Color(0xFF0F766E);
  static const Color accentColor = Color(0xFF9C27B0); // Purple
  static const Color backgroundLight = Color(0xFFFFFFFF); // White
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textMain = Color(0xFF1F2937); // Gray 800
  static const Color textSub = Color(0xFF6B7280); // Gray 500
  static const Color borderLight = Color(0xFFE5E7EB); // Gray 200
  
  // Legacy/Fallback Colors (Mapped to new identifiers where possible)
  static const Color errorColor = Color(0xFFEF4444);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color successColor = Color(0xFF10B981);

  // ── TEACH domain colours ──────────────────────────────────────────────────
  // The TEACH Primary manual colour-codes the three domains, and observers
  // trained on the manual read those colours as meaning. Requested by the
  // Mato Grosso (Brazil) TEACH coordinators.
  //
  // Each domain has three roles. `Accent` is for icons, borders and indicators;
  // `Tint` is a pale fill; `Text` is the only shade safe for text. The manual's
  // yellow sits near 1.9:1 on white — well under the 4.5:1 WCAG AA minimum — so
  // never render text in an `Accent` colour.
  //
  // TODO(W2b): confirm these hexes against the official manual once the
  // Portuguese write-up and its colour reference arrive.

  // Domain I — Classroom Culture (yellow)
  static const Color domainCultureAccent = Color(0xFFEAB308);
  static const Color domainCultureTint = Color(0xFFFEF3C7);
  static const Color domainCultureText = Color(0xFFA16207);

  // Domain II — Instruction (purple / magenta)
  static const Color domainInstructionAccent = Color(0xFFA21CAF);
  static const Color domainInstructionTint = Color(0xFFFAE8FF);
  static const Color domainInstructionText = Color(0xFFA21CAF);

  // Domain III — Socioemotional Skills (orange)
  static const Color domainSocioemotionalAccent = Color(0xFFEA580C);
  static const Color domainSocioemotionalTint = Color(0xFFFFEDD5);
  static const Color domainSocioemotionalText = Color(0xFFC2410C);

  // Gradients
  static const LinearGradient quoteGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF14B8A5), Color(0xFF0D9488)],
  );
  
  static const LinearGradient micGradient = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [Color(0xFF0D9488), Color(0xFF2DD4BF)],
  );

  static ThemeData getLightTheme([Color? customPrimary]) {
    final effectivePrimary = customPrimary ?? primaryColor;
    return ThemeData(
      useMaterial3: true,
      primaryColor: effectivePrimary,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: ColorScheme.light(
        primary: effectivePrimary,
        secondary: accentColor,
        surface: surfaceLight,
        onPrimary: Colors.white,
        onSurface: textMain,
        error: errorColor,
      ),
      
      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: effectivePrimary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor),
        ),
        hintStyle: GoogleFonts.inter(
          color: Colors.grey.shade400,
          fontSize: 14,
        ),
      ),

      // ElevatedButton Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: effectivePrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Typography
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 64, 
          fontWeight: FontWeight.bold, 
          color: textMain,
          height: 1.0,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 32, 
          fontWeight: FontWeight.bold, 
          color: textMain,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 24, 
          fontWeight: FontWeight.bold, 
          color: textMain,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 20, 
          fontWeight: FontWeight.bold, 
          color: textMain,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16, 
          color: textMain,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14, 
          color: textSub,
        ),
      ),
      
      // Card Theme
      cardTheme: CardThemeData(
        color: surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderLight),
        ),
        margin: EdgeInsets.zero,
      ),

      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          color: textMain,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: textMain),
      ),
      
      dividerColor: Colors.grey.shade200,
    );
  }
  

  static ThemeData getDarkTheme([Color? customPrimary]) {
    final effectivePrimary = customPrimary ?? primaryColor;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: effectivePrimary,
      scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
      colorScheme: ColorScheme.dark(
        primary: effectivePrimary,
        secondary: accentColor,
        surface: const Color(0xFF1E293B), // Slate 800
        onPrimary: Colors.white,
        onSurface: Colors.white,
        error: errorColor,
      ),
      
      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: effectivePrimary),
        ),
        hintStyle: GoogleFonts.inter(
          color: Colors.grey.shade500,
          fontSize: 14,
        ),
      ),

      // ElevatedButton Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: effectivePrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Typography
      textTheme: GoogleFonts.interTextTheme().apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ).copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 64, 
          fontWeight: FontWeight.bold, 
          color: Colors.white,
          height: 1.0,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 32, 
          fontWeight: FontWeight.bold, 
          color: Colors.white,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 24, 
          fontWeight: FontWeight.bold, 
          color: Colors.white,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 20, 
          fontWeight: FontWeight.bold, 
          color: Colors.white,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16, 
          color: Colors.white,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14, 
          color: Colors.grey.shade400,
        ),
      ),
      
      // Card Theme
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade700),
        ),
        margin: EdgeInsets.zero,
      ),

      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      
      dividerColor: Colors.grey.shade800,
    );
  }
  
  // Helpers
  static Color getScoreColor(num score) {
    if (score >= 4) return successColor;
    if (score >= 3) return warningColor;
    return errorColor;
  }
  
  static Color getScoreColorDouble(num score) {
    if (score >= 4.0) return successColor;
    if (score >= 3.0) return warningColor;
    return errorColor;
  }
}


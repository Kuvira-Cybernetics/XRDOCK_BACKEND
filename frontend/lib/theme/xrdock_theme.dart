import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class XRDockTheme {
  static const Color primaryBlue = Color(0xFF007BFF);
  static const Color neonCyan = Color(0xFF00F2FF);
  static const Color deepNavy = Color(0xFF000A1A);

  static ThemeData get lightTheme {
    return ThemeData.light().copyWith(
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      primaryColor: primaryBlue,
      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        secondary: neonCyan,
        surface: Colors.white,
      ),
      textTheme: GoogleFonts.exo2TextTheme(ThemeData.light().textTheme)
          .copyWith(
            displayLarge: GoogleFonts.orbitron(
              color: deepNavy,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
            titleLarge: GoogleFonts.orbitron(
              color: deepNavy,
              fontWeight: FontWeight.w600,
            ),
          ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: deepNavy,
      primaryColor: neonCyan,
      colorScheme: const ColorScheme.dark(
        primary: neonCyan,
        secondary: primaryBlue,
        surface: Color(0xFF001529),
      ),
      textTheme: GoogleFonts.exo2TextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.orbitron(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          letterSpacing: 2.0,
          shadows: [const Shadow(color: neonCyan, blurRadius: 15)],
        ),
        titleLarge: GoogleFonts.orbitron(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: neonCyan.withOpacity(0.1),
          foregroundColor: neonCyan,
          side: const BorderSide(color: neonCyan, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: neonCyan, width: 2),
        ),
      ),
    );
  }
}

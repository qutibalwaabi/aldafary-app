
import 'package:flutter/material.dart';

// FINAL, CORRECTED, AND CENTRALIZED COLOR SCHEME
class AppColors {
  // --- Brand Colors --- 
  static const Color primaryMaroon = Color(0xFF800000);
  static const Color accentGold = Color(0xFFE8B81C);

  // --- Dark Theme (for Login Screen) ---
  static const Color darkBackground = Color(0xFF1B0B0B);
  static const Color darkSurface = Color(0xFF330000);

  // --- Light Theme (for main app screens) ---
  static const Color lightBackground = Color(0xFFFAFAFA); // Off-white/Creamy
  static const Color lightSurface = Colors.white;      // White for cards

  // --- Text Colors ---
  static const Color textOnDark = Colors.white;
  static const Color textOnLight = Colors.black87;
  static const Color textOnAccent = Colors.black;
  static const Color secondaryText = Colors.white70; // For hints on dark theme
}

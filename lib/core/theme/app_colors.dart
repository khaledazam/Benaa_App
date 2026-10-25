import 'package:flutter/material.dart';

/// Centralized Enterprise Design System Color Tokens for Benaa
class AppColors {
  // Core Enterprise Brand Palette
  static const Color primary = Color(0xFF1E3A5F);       // Deep Enterprise Navy
  static const Color primaryDark = Color(0xFF142A45);   // Midnight Navy
  static const Color primaryLight = Color(0xFF2B4D7B);  // Soft Navy

  // Surfaces & Backgrounds
  static const Color background = Color(0xFFF8FAFC);    // Crisp Slate Gray-White
  static const Color surface = Color(0xFFFFFFFF);       // Clean Pure White
  static const Color surfaceMuted = Color(0xFFF1F5F9);  // Subtle Table/Card Muted Surface
  static const Color border = Color(0xFFE2E8F0);        // Fine Enterprise Divider
  static const Color borderSubtle = Color(0xFFEDF2F7);

  // Typography (Sharpened contrast for mobile and warehouse floor lighting)
  static const Color textPrimary = Color(0xFF0F172A);   // Deep Slate 900
  static const Color textSecondary = Color(0xFF475569); // Rich Slate 600
  static const Color textMuted = Color(0xFF64748B);     // Accessible Slate 500

  // Semantic Status Tokens
  static const Color success = Color(0xFF16856A);       // Restrained Enterprise Emerald
  static const Color successLight = Color(0xFFE6F4EA);  // Emerald Tint
  static const Color warning = Color(0xFFD99520);       // Warm Saudi Amber
  static const Color warningLight = Color(0xFFFEF3C7);  // Amber Tint
  static const Color error = Color(0xFFC83B3B);         // Restrained Commercial Crimson
  static const Color errorLight = Color(0xFFFDE8E8);    // Crimson Tint
  static const Color info = Color(0xFF1E3A5F);          // Semantic Info uses Primary Navy
  static const Color infoLight = Color(0xFFEBF5FF);

  // Aliases for backward compatibility with existing codebase
  static const Color danger = error;
  static const Color dangerLight = errorLight;
  static const Color primaryAccent = primary;
  static const Color bgDark = Color(0xFF0F172A);
  static const Color bgSurface = Color(0xFF1E293B);
  static const Color bgCard = surface;
  static const Color bgLight = background;
  static const Color cardLight = surface;
  static const Color textDarkPrimary = textPrimary;
  static const Color textDarkSecondary = textSecondary;
  static const Color borderDark = Color(0xFF334155);
  static const Color borderLight = border;

  // Dynamic Theme-Aware Color Helpers
  static Color getBg(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F172A) : background;
  }

  static Color getCardBg(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : surface;
  }

  static Color getSurfaceBg(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : surfaceMuted;
  }

  static Color getTextPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF8FAFC) : textPrimary;
  }

  static Color getTextSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : textSecondary;
  }

  static Color getBorder(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : border;
  }
}

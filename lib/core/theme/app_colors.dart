import 'package:flutter/material.dart';

class AppColors {
  // Primary Palette (Deep Indigo & Construction Amber accents)
  static const Color primary = Color(0xFF1E293B);       // Slate Dark
  static const Color primaryAccent = Color(0xFF2563EB); // Vibrant Royal Blue
  static const Color secondary = Color(0xFF0F172A);     // Deep Obsidian

  // Status & Accents
  static const Color success = Color(0xFF10B981);       // Emerald Green
  static const Color warning = Color(0xFFF59E0B);       // Amber Orange
  static const Color danger = Color(0xFFEF4444);        // Crimson Red
  static const Color info = Color(0xFF06B6D4);          // Cyan Info

  // Backgrounds
  static const Color bgDark = Color(0xFF0B0F17);
  static const Color bgSurface = Color(0xFF1E293B);
  static const Color bgCard = Color(0xFF182232);
  static const Color bgLight = Color(0xFFF1F5F9);
  static const Color cardLight = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textDarkPrimary = Color(0xFF0F172A);
  static const Color textDarkSecondary = Color(0xFF475569);

  // Borders & Dividers
  static const Color borderDark = Color(0xFF334155);
  static const Color borderLight = Color(0xFFCBD5E1);

  // Dynamic Theme-Aware Color Helpers
  static Color getBg(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? bgDark : bgLight;
  }

  static Color getCardBg(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? bgCard : cardLight;
  }

  static Color getSurfaceBg(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? bgSurface : const Color(0xFFE2E8F0);
  }

  static Color getTextPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? textPrimary : textDarkPrimary;
  }

  static Color getTextSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? textSecondary : textDarkSecondary;
  }

  static Color getBorder(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? borderDark : borderLight;
  }
}

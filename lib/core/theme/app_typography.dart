import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Centralized Enterprise Arabic Typography System for Benaa
class AppTypography {
  static TextStyle _font({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double? height,
    double? letterSpacing,
  }) {
    try {
      return GoogleFonts.ibmPlexSansArabic(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height ?? 1.35,
        letterSpacing: letterSpacing,
      );
    } catch (_) {
      return GoogleFonts.tajawal(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height ?? 1.35,
        letterSpacing: letterSpacing,
      );
    }
  }

  // 1. Screen Title: 22sp
  static TextStyle screenTitle({Color color = AppColors.textPrimary}) {
    return _font(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: color,
      height: 1.3,
    );
  }

  // 2. Section Heading: 17sp
  static TextStyle sectionHeading({Color color = AppColors.textPrimary}) {
    return _font(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: color,
      height: 1.35,
    );
  }

  // 3. Card Title: 15.5sp
  static TextStyle cardTitle({Color color = AppColors.textPrimary}) {
    return _font(
      fontSize: 15.5,
      fontWeight: FontWeight.w600,
      color: color,
      height: 1.35,
    );
  }

  // 4. Body: 14sp
  static TextStyle body({Color color = AppColors.textPrimary}) {
    return _font(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: color,
      height: 1.4,
    );
  }

  // 4b. Body Bold: 14sp
  static TextStyle bodyBold({Color color = AppColors.textPrimary}) {
    return _font(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: color,
      height: 1.4,
    );
  }

  // 5. Secondary / Caption: 13sp
  static TextStyle secondary({Color color = AppColors.textSecondary}) {
    return _font(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: color,
      height: 1.35,
    );
  }

  // 6. Small Labels / Badges: 12sp
  static TextStyle smallLabel({Color color = AppColors.textSecondary}) {
    return _font(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: color,
      height: 1.25,
    );
  }

  // 7. Tabular Numbers / Currency Display
  static TextStyle tabularNumber({
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.w700,
    Color color = AppColors.textPrimary,
  }) {
    return _font(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: 1.2,
    );
  }

  // 8. Caption: 11.5sp
  static TextStyle caption({Color color = AppColors.textSecondary}) {
    return _font(
      fontSize: 11.5,
      fontWeight: FontWeight.w500,
      color: color,
      height: 1.3,
    );
  }

  // 9. Button: 13.5sp
  static TextStyle button({Color color = AppColors.textPrimary}) {
    return _font(
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      color: color,
      height: 1.25,
    );
  }
}

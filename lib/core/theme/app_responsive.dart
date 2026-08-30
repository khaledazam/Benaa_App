import 'package:flutter/material.dart';

/// كلاس ذكي لإدارة مقاسات وتجاوب شاشات الهاتف والأجهزة اللوحية (Responsive Helper)
class AppResponsive {
  static double screenWidth(BuildContext context) => MediaQuery.of(context).size.width;
  static double screenHeight(BuildContext context) => MediaQuery.of(context).size.height;

  static bool isSmallPhone(BuildContext context) => screenWidth(context) < 360;
  static bool isTablet(BuildContext context) => screenWidth(context) >= 600;
  static bool isDesktop(BuildContext context) => screenWidth(context) >= 1024;

  /// حساب عامل التحجيم بناءً على عرض الشاشة القياسي للجوالات (390px)
  static double scaleFactor(BuildContext context) {
    final width = screenWidth(context);
    if (width >= 1024) return 1.25;
    if (width >= 600) return 1.15;
    if (width < 340) return 0.9;
    return width / 390.0;
  }

  /// حساب حجم الخط الديناميكي مع حد أدنى وأقصى لحماية النصوص
  static double fontSize(BuildContext context, double baseSize) {
    final factor = scaleFactor(context);
    final calculated = baseSize * factor;
    // التأكد من أن الخط لا يصغر عن 85% ولا يكبر عن 135% من الحجم الأصلي
    return calculated.clamp(baseSize * 0.85, baseSize * 1.35);
  }

  /// حساب حجم الأيقونة الديناميكي لضمان الوضوح العالي على كافة الشاشات
  static double iconSize(BuildContext context, double baseSize) {
    final factor = scaleFactor(context);
    final calculated = baseSize * factor;
    // ضمان ألا تقل الأيقونة عن 20px لأداء واستجابة بصرية مريحة للعين
    return calculated.clamp(20.0, baseSize * 1.4);
  }

  /// حساب المسافات والحواشي (Padding / Margin) المتجاوبة
  static double space(BuildContext context, double baseValue) {
    final factor = scaleFactor(context);
    return (baseValue * factor).clamp(baseValue * 0.75, baseValue * 1.5);
  }

  /// حساب عدد أعمدة الـ Grid حسب عرض الشاشة
  static int gridCrossAxisCount(BuildContext context, {int mobile = 2, int tablet = 3, int desktop = 4}) {
    final width = screenWidth(context);
    if (width >= 1024) return desktop;
    if (width >= 600) return tablet;
    if (width < 350) return mobile > 1 ? mobile - 1 : 1;
    return mobile;
  }

  /// إرجاع قيمة متغيرة بحسب نوع الجهاز
  static T responsiveValue<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context) && desktop != null) return desktop;
    if (isTablet(context) && tablet != null) return tablet;
    return mobile;
  }
}

import 'package:flutter/material.dart';

enum ArchivePeriodType {
  today,
  thisWeek,
  thisMonth,
  allTime,
  custom,
}

class PeriodArchiveFilterService {
  /// Parses various date string formats safely (ISO-8601, dd-MM-yyyy, dd/MM/yyyy, timestamps, etc.)
  static DateTime? parseFlexibleDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    final clean = dateStr.trim();

    // 1. Try ISO-8601 first (e.g. 2026-09-03, 2026-09-03T14:30:00, 2026/09/03)
    try {
      final isoCandidate = clean.replaceAll('/', '-');
      final parsed = DateTime.tryParse(isoCandidate);
      if (parsed != null) return parsed;
    } catch (_) {}

    // 2. Try dd-MM-yyyy or dd/MM/yyyy
    final parts = clean.split(RegExp(r'[-/\s]'));
    if (parts.length >= 3) {
      final p0 = int.tryParse(parts[0]);
      final p1 = int.tryParse(parts[1]);
      final p2 = int.tryParse(parts[2]);
      if (p0 != null && p1 != null && p2 != null) {
        if (p0 > 1000) {
          // yyyy-MM-dd
          return DateTime(p0, p1, p2);
        } else if (p2 > 1000) {
          // dd-MM-yyyy
          return DateTime(p2, p1, p0);
        }
      }
    }

    // 3. Try integer timestamp in milliseconds or seconds
    final numVal = int.tryParse(clean);
    if (numVal != null) {
      if (clean.length >= 12) {
        return DateTime.fromMillisecondsSinceEpoch(numVal);
      } else if (clean.length == 10) {
        return DateTime.fromMillisecondsSinceEpoch(numVal * 1000);
      }
    }

    return null;
  }

  /// Checks if a DateTime object falls within the specified period
  static bool isDateInPeriod({
    required DateTime date,
    required ArchivePeriodType periodType,
    DateTimeRange? customRange,
  }) {
    final now = DateTime.now();

    switch (periodType) {
      case ArchivePeriodType.today:
        return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;

      case ArchivePeriodType.thisWeek:
        // Arab work-week: Saturday (السبت) to Friday (الجمعة)
        // DateTime.weekday: Mon=1, Tue=2, Wed=3, Thu=4, Fri=5, Sat=6, Sun=7
        final daysSinceSaturday = (now.weekday + 1) % 7;
        final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysSinceSaturday));
        final endOfWeek = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day, 23, 59, 59).add(const Duration(days: 6));
        return (date.isAtSameMomentAs(startOfWeek) || date.isAfter(startOfWeek)) &&
            (date.isAtSameMomentAs(endOfWeek) || date.isBefore(endOfWeek));

      case ArchivePeriodType.thisMonth:
        return date.year == now.year && date.month == now.month;

      case ArchivePeriodType.allTime:
        return true;

      case ArchivePeriodType.custom:
        if (customRange == null) return true;
        final start = DateTime(customRange.start.year, customRange.start.month, customRange.start.day);
        final end = DateTime(customRange.end.year, customRange.end.month, customRange.end.day, 23, 59, 59);
        return (date.isAtSameMomentAs(start) || date.isAfter(start)) &&
            (date.isAtSameMomentAs(end) || date.isBefore(end));
    }
  }

  /// Checks if a date string falls within the specified period
  static bool isDateStringInPeriod({
    required String? dateStr,
    required ArchivePeriodType periodType,
    DateTimeRange? customRange,
  }) {
    if (periodType == ArchivePeriodType.allTime) return true;
    if (dateStr == null || dateStr.trim().isEmpty) return false;

    final parsed = parseFlexibleDate(dateStr);
    if (parsed == null) return false;

    return isDateInPeriod(date: parsed, periodType: periodType, customRange: customRange);
  }

  static String getPeriodTitle(ArchivePeriodType type, {DateTimeRange? customRange}) {
    switch (type) {
      case ArchivePeriodType.today:
        return 'أرشيف اليوم 📅';
      case ArchivePeriodType.thisWeek:
        return 'أرشيف هذا الأسبوع 🗓️';
      case ArchivePeriodType.thisMonth:
        return 'أرشيف هذا الشهر 📆';
      case ArchivePeriodType.allTime:
        return 'الأرشيف الكامل 📁';
      case ArchivePeriodType.custom:
        if (customRange != null) {
          final start = customRange.start.toString().split(' ').first;
          final end = customRange.end.toString().split(' ').first;
          return 'فترة من $start إلى $end 🔍';
        }
        return 'تاريخ مخصص 🔍';
    }
  }
}

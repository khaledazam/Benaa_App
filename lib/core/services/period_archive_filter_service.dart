import 'package:flutter/material.dart';

enum ArchivePeriodType {
  today,
  thisWeek,
  thisMonth,
  allTime,
  custom,
}

class PeriodArchiveFilterService {
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
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final cleanStart = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        return date.isAfter(cleanStart.subtract(const Duration(seconds: 1)));

      case ArchivePeriodType.thisMonth:
        return date.year == now.year && date.month == now.month;

      case ArchivePeriodType.allTime:
        return true;

      case ArchivePeriodType.custom:
        if (customRange == null) return true;
        final start = DateTime(customRange.start.year, customRange.start.month, customRange.start.day);
        final end = DateTime(customRange.end.year, customRange.end.month, customRange.end.day, 23, 59, 59);
        return date.isAfter(start.subtract(const Duration(seconds: 1))) &&
            date.isBefore(end.add(const Duration(seconds: 1)));
    }
  }

  static bool isDateStringInPeriod({
    required String dateStr,
    required ArchivePeriodType periodType,
    DateTimeRange? customRange,
  }) {
    if (dateStr.isEmpty) return true;
    try {
      final parsed = DateTime.parse(dateStr);
      return isDateInPeriod(date: parsed, periodType: periodType, customRange: customRange);
    } catch (_) {
      return true;
    }
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

import 'package:flutter_test/flutter_test.dart';
import 'package:benaa_flutter_mobile/core/services/period_archive_filter_service.dart';

void main() {
  group('PeriodArchiveFilterService Unit Tests', () {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    final twoWeeksAgo = now.subtract(const Duration(days: 14));
    final twoWeeksAgoStr = '${twoWeeksAgo.year}-${twoWeeksAgo.month.toString().padLeft(2, '0')}-${twoWeeksAgo.day.toString().padLeft(2, '0')}';

    test('Today filter matches only today and excludes yesterday', () {
      expect(
        PeriodArchiveFilterService.isDateStringInPeriod(
          dateStr: todayStr,
          periodType: ArchivePeriodType.today,
        ),
        isTrue,
      );

      expect(
        PeriodArchiveFilterService.isDateStringInPeriod(
          dateStr: yesterdayStr,
          periodType: ArchivePeriodType.today,
        ),
        isFalse,
      );

      expect(
        PeriodArchiveFilterService.isDateStringInPeriod(
          dateStr: twoWeeksAgoStr,
          periodType: ArchivePeriodType.today,
        ),
        isFalse,
      );
    });

    test('Flexible date string formats parse correctly (dd-MM-yyyy, ISO)', () {
      final ddMmYyyyToday = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
      final ddMmYyyyYesterday = '${yesterday.day.toString().padLeft(2, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.year}';

      expect(
        PeriodArchiveFilterService.isDateStringInPeriod(
          dateStr: ddMmYyyyToday,
          periodType: ArchivePeriodType.today,
        ),
        isTrue,
      );

      expect(
        PeriodArchiveFilterService.isDateStringInPeriod(
          dateStr: ddMmYyyyYesterday,
          periodType: ArchivePeriodType.today,
        ),
        isFalse,
      );
    });

    test('All-Time period returns true for any valid or invalid date', () {
      expect(
        PeriodArchiveFilterService.isDateStringInPeriod(
          dateStr: twoWeeksAgoStr,
          periodType: ArchivePeriodType.allTime,
        ),
        isTrue,
      );
      expect(
        PeriodArchiveFilterService.isDateStringInPeriod(
          dateStr: '',
          periodType: ArchivePeriodType.allTime,
        ),
        isTrue,
      );
    });

    test('Invalid/Empty date strings return false for specific periods', () {
      expect(
        PeriodArchiveFilterService.isDateStringInPeriod(
          dateStr: 'invalid-date',
          periodType: ArchivePeriodType.today,
        ),
        isFalse,
      );
      expect(
        PeriodArchiveFilterService.isDateStringInPeriod(
          dateStr: '',
          periodType: ArchivePeriodType.today,
        ),
        isFalse,
      );
    });
  });
}

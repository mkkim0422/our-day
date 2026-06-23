import 'package:flutter_test/flutter_test.dart';
import 'package:our_day/core/constants/enums.dart';
import 'package:our_day/core/utils/backfill_dates.dart';

void main() {
  group('BackfillDates.suggest', () {
    test('monthly: 이번 달부터 한 달씩 과거로(최신순)', () {
      final now = DateTime(2026, 6, 23, 9);
      final dates = BackfillDates.suggest(ScheduleType.monthly, const {}, now, 3);

      expect(dates.length, 3);
      expect(dates[0].year, 2026);
      expect(dates[0].month, 6);
      expect(dates[1].month, 5);
      expect(dates[2].month, 4);
    });

    test('monthly: 말일 보정(3/31 → 2/28)', () {
      final now = DateTime(2026, 3, 31, 9);
      final dates = BackfillDates.suggest(ScheduleType.monthly, const {}, now, 2);

      expect(dates[1].year, 2026);
      expect(dates[1].month, 2);
      expect(dates[1].day, 28); // 2026-02는 28일까지.
    });

    test('yearly: 한 해씩 과거로', () {
      final now = DateTime(2026, 6, 23);
      final dates = BackfillDates.suggest(ScheduleType.yearly, const {}, now, 3);

      expect(dates.map((d) => d.year).toList(), [2026, 2025, 2024]);
    });

    test('weekly: 7일씩 과거로', () {
      final now = DateTime(2026, 6, 23);
      final dates = BackfillDates.suggest(ScheduleType.weekly, const {}, now, 2);

      expect(dates[1], now.subtract(const Duration(days: 7)));
    });

    test('fixedDates: 설정된 지정일(now 이전)을 최신순으로 사용', () {
      final now = DateTime(2026, 6, 23);
      final dates = BackfillDates.suggest(
        ScheduleType.fixedDates,
        const {
          'dates': ['2026-01-01', '2025-09-15', '2027-01-01'], // 미래(2027)는 제외.
        },
        now,
        2,
      );

      expect(dates.length, 2);
      expect(dates[0], DateTime(2026, 1, 1));
      expect(dates[1], DateTime(2025, 9, 15));
    });

    test('fixedDates: 설정 날짜가 모자라면 월 단위로 더 채운다', () {
      final now = DateTime(2026, 6, 23);
      final dates = BackfillDates.suggest(
        ScheduleType.fixedDates,
        const {
          'dates': ['2026-05-10'],
        },
        now,
        3,
      );

      expect(dates.length, 3);
      expect(dates[0], DateTime(2026, 5, 10));
      // 이후는 2026-05-10에서 월 단위로 거슬러 감.
      expect(dates[1].month, 4);
      expect(dates[2].month, 3);
    });

    test('count가 0 이하면 빈 목록', () {
      expect(
        BackfillDates.suggest(ScheduleType.monthly, const {}, DateTime(2026), 0),
        isEmpty,
      );
    });
  });
}

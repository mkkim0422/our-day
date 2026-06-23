import 'package:flutter_test/flutter_test.dart';
import 'package:our_day/core/constants/enums.dart';
import 'package:our_day/core/utils/reminder_time.dart';

void main() {
  group('nextPeriodReminder', () {
    test('manual은 알림 없음(null)', () {
      final r = ReminderTime.nextPeriodReminder(
          ScheduleType.manual, const {}, DateTime(2026, 6, 23, 9));
      expect(r, isNull);
    });

    test('monthly: 이번 달 지정일이 지났으면 다음 달', () {
      final from = DateTime(2026, 6, 23, 12);
      final r = ReminderTime.nextPeriodReminder(
          ScheduleType.monthly, {'day': 1, 'time': '10:00'}, from);
      expect(r, DateTime(2026, 7, 1, 10, 0));
    });

    test('monthly: 이번 달 지정일이 아직이면 이번 달', () {
      final from = DateTime(2026, 6, 23, 12);
      final r = ReminderTime.nextPeriodReminder(
          ScheduleType.monthly, {'day': 28, 'time': '10:00'}, from);
      expect(r, DateTime(2026, 6, 28, 10, 0));
    });

    test('monthly: 말일 보정(2월에 31일 지정 → 28일)', () {
      final from = DateTime(2026, 2, 1, 0);
      final r = ReminderTime.nextPeriodReminder(
          ScheduleType.monthly, {'day': 31}, from);
      expect(r, DateTime(2026, 2, 28, 10, 0)); // 2026-02는 28일까지
    });

    test('yearly: 올해 기념일이 지났으면 내년', () {
      final from = DateTime(2026, 6, 23, 12);
      final r = ReminderTime.nextPeriodReminder(
          ScheduleType.yearly, {'month': 6, 'day': 23, 'time': '09:00'}, from);
      expect(r, DateTime(2027, 6, 23, 9, 0));
    });

    test('weekly: 다음 해당 요일로 예약', () {
      // 2026-06-23은 화요일(weekday=2). 토요일(6) 지정 → 같은 주 27일.
      final from = DateTime(2026, 6, 23, 12);
      final r = ReminderTime.nextPeriodReminder(
          ScheduleType.weekly, {'weekday': 6, 'time': '10:00'}, from);
      expect(r, DateTime(2026, 6, 27, 10, 0));
    });

    test('fixedDates: from 이후 가장 가까운 날', () {
      final from = DateTime(2026, 6, 23, 12);
      final r = ReminderTime.nextPeriodReminder(
        ScheduleType.fixedDates,
        {
          'dates': ['2026-01-01', '2026-09-15', '2027-01-01']
        },
        from,
      );
      expect(r, DateTime(2026, 9, 15, 10, 0));
    });

    test('fixedDates: 남은 날 없으면 null', () {
      final from = DateTime(2026, 6, 23, 12);
      final r = ReminderTime.nextPeriodReminder(
          ScheduleType.fixedDates, {'dates': ['2026-01-01']}, from);
      expect(r, isNull);
    });
  });

  group('nextAnniversary', () {
    test('올해 기념일이 지났으면 내년 같은 날', () {
      final past = DateTime(2025, 6, 10, 14);
      final from = DateTime(2026, 6, 23, 12);
      final r = ReminderTime.nextAnniversary(past, from);
      expect(r, DateTime(2027, 6, 10, 10, 0));
    });

    test('올해 기념일이 아직이면 올해', () {
      final past = DateTime(2025, 12, 25, 14);
      final from = DateTime(2026, 6, 23, 12);
      final r = ReminderTime.nextAnniversary(past, from);
      expect(r, DateTime(2026, 12, 25, 10, 0));
    });
  });
}

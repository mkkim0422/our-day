import '../constants/enums.dart';

/// 촬영 주기(schedule_type/schedule_config)로 알림 시각을 계산한다 (6장 리텐션).
///
/// 반환값은 모두 **로컬 벽시계 기준 DateTime**. 실제 예약 시 NotificationService가
/// timezone(TZDateTime)으로 변환한다(서비스 계층 격리, 8장).
class ReminderTime {
  const ReminderTime._();

  /// 다음 "이번 기간 한 컷" 알림 시각([from] 이후 가장 가까운 시점).
  /// `manual`은 알림을 두지 않으므로 null.
  static DateTime? nextPeriodReminder(
    ScheduleType type,
    Map<String, dynamic> config,
    DateTime from,
  ) {
    final (h, m) = _time(config['time'] as String?);
    switch (type) {
      case ScheduleType.manual:
        return null;
      case ScheduleType.daily:
        var c = DateTime(from.year, from.month, from.day, h, m);
        if (!c.isAfter(from)) c = c.add(const Duration(days: 1));
        return c;
      case ScheduleType.weekly:
        final weekday = (config['weekday'] as int?) ?? from.weekday;
        return _nextWeekday(from, weekday, h, m);
      case ScheduleType.biweekly:
        final weekday = (config['weekday'] as int?) ?? from.weekday;
        var next = _nextWeekday(from, weekday, h, m);
        final anchor = _parseDate(config['anchor_date'] as String?);
        // anchor 주와 짝이 안 맞으면 한 주 더 미뤄 격주 간격(14일) 유지.
        if (anchor != null) {
          final days = DateTime(next.year, next.month, next.day)
              .difference(DateTime(anchor.year, anchor.month, anchor.day))
              .inDays;
          if (days % 14 != 0) next = next.add(const Duration(days: 7));
        }
        return next;
      case ScheduleType.monthly:
        final day = (config['day'] as int?) ?? from.day;
        return _nextMonthly(from, day, h, m);
      case ScheduleType.yearly:
        final month = (config['month'] as int?) ?? from.month;
        final day = (config['day'] as int?) ?? from.day;
        return _nextYearly(from, month, day, h, m);
      case ScheduleType.fixedDates:
        final dates = (config['dates'] as List?)?.cast<dynamic>() ?? const [];
        final upcoming = dates
            .map((e) => _parseDate(e as String?))
            .whereType<DateTime>()
            .map((d) => DateTime(d.year, d.month, d.day, h, m))
            .where((d) => d.isAfter(from))
            .toList()
          ..sort();
        return upcoming.isEmpty ? null : upcoming.first;
    }
  }

  /// 회상 알림용 다음 기념일([from] 이후 가장 가까운, 과거 촬영과 같은 월·일).
  /// "작년 오늘, 가족은 이런 모습이었어요"(6장 2번)에 사용.
  static DateTime nextAnniversary(
    DateTime past,
    DateTime from, {
    int hour = 10,
    int minute = 0,
  }) {
    var candidate = DateTime(
        from.year, past.month, _clampDay(from.year, past.month, past.day), hour, minute);
    if (!candidate.isAfter(from)) {
      candidate = DateTime(from.year + 1, past.month,
          _clampDay(from.year + 1, past.month, past.day), hour, minute);
    }
    return candidate;
  }

  // --- 내부 헬퍼 ---

  static (int, int) _time(String? s) {
    if (s == null || s.isEmpty) return (10, 0);
    final parts = s.split(':');
    final h = int.tryParse(parts.first) ?? 10;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return (h.clamp(0, 23), m.clamp(0, 59));
  }

  static DateTime? _parseDate(String? s) =>
      (s == null || s.isEmpty) ? null : DateTime.tryParse(s);

  static DateTime _nextWeekday(DateTime from, int weekday, int h, int m) {
    var d = DateTime(from.year, from.month, from.day, h, m);
    // 요일이 맞고 [from] 이후가 될 때까지 하루씩 전진(최대 7회).
    while (d.weekday != weekday || !d.isAfter(from)) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  static DateTime _nextMonthly(DateTime from, int day, int h, int m) {
    var year = from.year;
    var month = from.month;
    var candidate = DateTime(year, month, _clampDay(year, month, day), h, m);
    if (!candidate.isAfter(from)) {
      month++;
      if (month > 12) {
        month = 1;
        year++;
      }
      candidate = DateTime(year, month, _clampDay(year, month, day), h, m);
    }
    return candidate;
  }

  static DateTime _nextYearly(DateTime from, int month, int day, int h, int m) {
    var candidate =
        DateTime(from.year, month, _clampDay(from.year, month, day), h, m);
    if (!candidate.isAfter(from)) {
      candidate = DateTime(
          from.year + 1, month, _clampDay(from.year + 1, month, day), h, m);
    }
    return candidate;
  }

  /// 월 말일을 넘는 day(예: 2월 31일)를 그 달 마지막 날로 보정.
  static int _clampDay(int year, int month, int day) {
    final lastDay = DateTime(year, month + 1, 0).day; // 다음달 0일 = 이번달 말일
    return day.clamp(1, lastDay);
  }
}

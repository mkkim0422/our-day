/// 이벤트 페그(생일·명절·계절)별 다음 알림 시각 계산 (6장 리텐션).
///
/// 모두 **로컬 벽시계 기준**으로 아침 10시에 맞춘 DateTime을 돌려준다.
/// NotificationService가 실제 예약 시 timezone으로 변환한다(계층 격리, 8장).
class EventPegDates {
  const EventPegDates._();

  static const int hour = 10; // 발송 시각 — 아침 10시.

  /// 생일: 선택한 [birthday]의 월·일로 [from] 이후 가장 가까운 해.
  static DateTime nextBirthday(DateTime birthday, DateTime from) {
    var c = DateTime(from.year, birthday.month,
        _clampDay(from.year, birthday.month, birthday.day), hour);
    if (!c.isAfter(from)) {
      c = DateTime(from.year + 1, birthday.month,
          _clampDay(from.year + 1, birthday.month, birthday.day), hour);
    }
    return c;
  }

  /// 계절: 봄(3/1)·여름(6/1)·가을(9/1)·겨울(12/1) 중 [from] 이후 가장 가까운 날.
  static DateTime nextSeasonStart(DateTime from) {
    const months = [3, 6, 9, 12];
    final candidates = <DateTime>[];
    for (final y in [from.year, from.year + 1]) {
      for (final m in months) {
        candidates.add(DateTime(y, m, 1, hour));
      }
    }
    candidates.sort();
    return candidates.firstWhere((d) => d.isAfter(from));
  }

  /// 명절(설날·추석): [from] 이후 가장 가까운 명절. 음력→양력은 연도별 표로 보관.
  /// 표에 없는 미래 연도는 null(그 시점엔 앱 사용 중 재예약되며 표를 갱신하면 됨).
  static DateTime? nextHoliday(DateTime from) {
    final upcoming = _holidays
        .map((d) => DateTime(d.year, d.month, d.day, hour))
        .where((d) => d.isAfter(from))
        .toList()
      ..sort();
    return upcoming.isEmpty ? null : upcoming.first;
  }

  /// 설날·추석 양력 날짜표(2025~2035). 음력 기반이라 매년 양력일이 달라진다.
  static final List<DateTime> _holidays = [
    DateTime(2025, 1, 29), DateTime(2025, 10, 6), // 설날·추석 2025
    DateTime(2026, 2, 17), DateTime(2026, 9, 25), // 2026
    DateTime(2027, 2, 6), DateTime(2027, 9, 15), // 2027
    DateTime(2028, 1, 27), DateTime(2028, 10, 3), // 2028
    DateTime(2029, 2, 13), DateTime(2029, 9, 22), // 2029
    DateTime(2030, 2, 3), DateTime(2030, 9, 12), // 2030
    DateTime(2031, 1, 23), DateTime(2031, 10, 1), // 2031
    DateTime(2032, 2, 11), DateTime(2032, 9, 19), // 2032
    DateTime(2033, 1, 31), DateTime(2033, 9, 8), // 2033
    DateTime(2034, 2, 19), DateTime(2034, 9, 27), // 2034
    DateTime(2035, 2, 8), DateTime(2035, 9, 16), // 2035
  ];

  static int _clampDay(int year, int month, int day) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return day.clamp(1, lastDay);
  }
}

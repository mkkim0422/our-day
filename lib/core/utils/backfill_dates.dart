import '../constants/enums.dart';

/// 과거 일괄 채우기(backfill, ②-1 입력경로 3)용 기본 날짜 추천.
///
/// 신규 사용자가 예전 사진 여러 장을 한 번에 넣을 때, 기본값으로 **프로젝트 주기에
/// 맞춰 과거로 한 칸씩** 거슬러 배치한다(예: 월간 → 이번 달·지난달·지지난달…).
/// 그러면 사진들이 자연히 서로 다른 기간을 채워 빈 타임라인이 즉시 메워진다.
/// 각 날짜는 사용자가 화면에서 개별 수정 가능(이 값은 어디까지나 출발점).
class BackfillDates {
  const BackfillDates._();

  /// 가장 최근([now])부터 과거로 [count]개의 추천 촬영일을 만든다(최신순).
  static List<DateTime> suggest(
    ScheduleType type,
    Map<String, dynamic> config,
    DateTime now,
    int count,
  ) {
    if (count <= 0) return const [];

    // 지정일 주기는 설정된 날짜(now 이전) 중 최신부터 사용.
    if (type == ScheduleType.fixedDates) {
      final raw = (config['dates'] as List?)?.cast<Object?>() ?? const [];
      final parsed = raw
          .map((e) => DateTime.tryParse('$e'))
          .whereType<DateTime>()
          .where((d) => !d.isAfter(now))
          .toList()
        ..sort((a, b) => b.compareTo(a));

      final result = parsed.take(count).toList();
      // 설정된 날짜가 모자라면 나머지는 월 단위로 더 거슬러 채운다.
      var anchor = result.isNotEmpty ? result.last : now;
      while (result.length < count) {
        anchor = _stepBack(ScheduleType.monthly, anchor);
        result.add(anchor);
      }
      return result;
    }

    final result = <DateTime>[];
    var d = now;
    for (var i = 0; i < count; i++) {
      result.add(d);
      d = _stepBack(type, d);
    }
    return result;
  }

  static DateTime _stepBack(ScheduleType type, DateTime d) {
    switch (type) {
      case ScheduleType.daily:
        return d.subtract(const Duration(days: 1));
      case ScheduleType.yearly:
        return DateTime(d.year - 1, d.month, d.day, 12);
      case ScheduleType.weekly:
        return d.subtract(const Duration(days: 7));
      case ScheduleType.biweekly:
        return d.subtract(const Duration(days: 14));
      case ScheduleType.monthly:
      case ScheduleType.fixedDates:
      case ScheduleType.manual:
        return _minusOneMonth(d);
    }
  }

  /// 한 달 전(말일 보정: 3/31 → 2/28).
  static DateTime _minusOneMonth(DateTime d) {
    final year = d.month == 1 ? d.year - 1 : d.year;
    final month = d.month == 1 ? 12 : d.month - 1;
    final lastDay = DateTime(year, month + 1, 0).day; // 다음 달 0일 = 이번 달 말일.
    final day = d.day > lastDay ? lastDay : d.day;
    return DateTime(year, month, day, 12);
  }
}

import '../constants/enums.dart';

/// 촬영 주기(schedule_type/schedule_config) 기반 "기간" 계산 (2장).
///
/// - [periodKey]: 한 시점이 속한 기간의 고유 키. "이번 기간에 이미 찍었는지"
///   판정과 진척 게이지(6장 4번) 계산에 사용.
/// - [periodLabel]: Capture에 저장할 표시용 라벨(예: "2026 · 6월").
class SchedulePeriod {
  const SchedulePeriod._();

  /// 한 [at] 시점이 속한 기간의 고유 키(중복 촬영 판정용).
  static String periodKey(
    ScheduleType type,
    Map<String, dynamic> config,
    DateTime at,
  ) {
    switch (type) {
      case ScheduleType.daily:
        return '${at.year}-${_two(at.month)}-${_two(at.day)}';
      case ScheduleType.yearly:
        return '${at.year}';
      case ScheduleType.monthly:
        return '${at.year}-${_two(at.month)}';
      case ScheduleType.weekly:
        final (y, w) = _isoWeek(at);
        return '$y-W${_two(w)}';
      case ScheduleType.biweekly:
        return _biweeklyKey(config, at);
      case ScheduleType.fixedDates:
        return '${at.year}-${_two(at.month)}-${_two(at.day)}';
      case ScheduleType.manual:
        return '${at.year}-${_two(at.month)}-${_two(at.day)}';
    }
  }

  /// Capture에 저장할 표시용 라벨.
  static String periodLabel(
    ScheduleType type,
    Map<String, dynamic> config,
    DateTime at,
  ) {
    switch (type) {
      case ScheduleType.daily:
        return '${at.year}.${_two(at.month)}.${_two(at.day)}';
      case ScheduleType.yearly:
        return '${at.year}';
      case ScheduleType.monthly:
        return '${at.year} · ${at.month}월';
      case ScheduleType.weekly:
      case ScheduleType.biweekly:
        final (y, w) = _isoWeek(at);
        return '$y · $w주차';
      case ScheduleType.fixedDates:
      case ScheduleType.manual:
        return '${at.year}.${_two(at.month)}.${_two(at.day)}';
    }
  }

  /// [now]가 속한 기간을 포함해 과거로 [count]개 기간의 대표 시점(최신→과거 순).
  ///
  /// 진척 스트립/스트릭(6장 4번) 계산용. 규칙적 주기가 없는 manual/fixedDates는
  /// 빈 리스트를 돌려준다(해당 유형은 캘린더/스트릭을 표시하지 않음).
  static List<DateTime> recentPeriodAnchors(
    ScheduleType type,
    Map<String, dynamic> config,
    DateTime now,
    int count,
  ) {
    final out = <DateTime>[];
    for (var i = 0; i < count; i++) {
      final at = _stepBack(type, now, i);
      if (at == null) break;
      out.add(at);
    }
    return out;
  }

  /// 진척 스트립의 기간 단위 라벨(예: "개월", "주").
  static String periodUnitLabel(ScheduleType type) {
    switch (type) {
      case ScheduleType.daily:
        return '일';
      case ScheduleType.weekly:
        return '주';
      case ScheduleType.biweekly:
        return '번';
      case ScheduleType.monthly:
        return '개월';
      case ScheduleType.yearly:
        return '년';
      case ScheduleType.fixedDates:
      case ScheduleType.manual:
        return '회';
    }
  }

  /// [now] 기준 [i]기간 전의 대표 시점. 규칙 주기가 없으면 null.
  static DateTime? _stepBack(ScheduleType type, DateTime now, int i) {
    switch (type) {
      case ScheduleType.daily:
        return now.subtract(Duration(days: i));
      case ScheduleType.weekly:
        return now.subtract(Duration(days: 7 * i));
      case ScheduleType.biweekly:
        return now.subtract(Duration(days: 14 * i));
      case ScheduleType.monthly:
        return DateTime(now.year, now.month - i, 1);
      case ScheduleType.yearly:
        return DateTime(now.year - i, 1, 1);
      case ScheduleType.fixedDates:
      case ScheduleType.manual:
        return null;
    }
  }

  // --- 내부 헬퍼 ---

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// 격주: anchor_date 기준 경과 주를 2로 나눈 묶음.
  static String _biweeklyKey(Map<String, dynamic> config, DateTime at) {
    final anchorStr = config['anchor_date'] as String?;
    final anchor =
        anchorStr != null ? DateTime.tryParse(anchorStr) : null;
    if (anchor == null) {
      final (y, w) = _isoWeek(at);
      return '$y-B${_two((w / 2).ceil())}';
    }
    final days = at.difference(anchor).inDays;
    final bucket = (days / 14).floor();
    return 'BW$bucket';
  }

  /// ISO-8601 주차(연도, 주). 월요일 시작.
  static (int, int) _isoWeek(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    // 해당 주의 목요일로 이동(ISO 규칙).
    final thursday = d.add(Duration(days: 4 - (d.weekday)));
    final firstThursday = DateTime(thursday.year, 1, 1).add(
      Duration(days: (4 - DateTime(thursday.year, 1, 1).weekday) % 7),
    );
    final week = 1 + (thursday.difference(firstThursday).inDays / 7).round();
    return (thursday.year, week);
  }
}

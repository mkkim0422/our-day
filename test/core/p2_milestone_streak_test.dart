import 'package:flutter_test/flutter_test.dart';
import 'package:our_day/core/constants/enums.dart';
import 'package:our_day/core/utils/milestone.dart';
import 'package:our_day/core/utils/schedule_period.dart';

void main() {
  group('Milestones.reached', () {
    final birth = DateTime(2025, 3, 20);

    test('백일 = 생후 100일', () {
      final now = DateTime(2025, 7, 1); // 백일(6/28) 지남, 돌 전.
      final ms = Milestones.reached(birth, now);
      expect(ms.map((m) => m.label), ['백일']);
      expect(ms.single.date, DateTime(2025, 6, 28)); // 3/20 + 100일
    });

    test('도달 전 마일스톤은 제외', () {
      final now = DateTime(2025, 5, 1); // 백일(6/28) 전.
      expect(Milestones.reached(birth, now), isEmpty);
    });

    test('돌·2살까지 순서대로', () {
      final now = DateTime(2027, 4, 1); // 백일·첫돌·2살 모두 지남.
      final labels = Milestones.reached(birth, now).map((m) => m.label).toList();
      expect(labels, ['백일', '첫 돌', '2살 생일']);
    });

    test('첫 돌은 생일 +1년', () {
      final ms = Milestones.reached(birth, DateTime(2026, 4, 1));
      final dol = ms.firstWhere((m) => m.label == '첫 돌');
      expect(dol.date, DateTime(2026, 3, 20));
    });
  });

  group('SchedulePeriod.recentPeriodAnchors', () {
    test('월간: 최신→과거 12개월, 월경계 정규화', () {
      final now = DateTime(2026, 2, 15);
      final anchors =
          SchedulePeriod.recentPeriodAnchors(ScheduleType.monthly, {}, now, 12);
      expect(anchors.length, 12);
      expect(anchors.first, DateTime(2026, 2, 1));
      expect(anchors[2], DateTime(2025, 12, 1)); // 2개월 전 → 작년 12월
    });

    test('주간: 7일 간격', () {
      final now = DateTime(2026, 6, 29);
      final anchors =
          SchedulePeriod.recentPeriodAnchors(ScheduleType.weekly, {}, now, 3);
      expect(anchors[1], now.subtract(const Duration(days: 7)));
    });

    test('manual은 규칙 주기 없음 → 빈 리스트', () {
      final anchors = SchedulePeriod.recentPeriodAnchors(
          ScheduleType.manual, {}, DateTime(2026, 6, 29), 12);
      expect(anchors, isEmpty);
    });
  });

  group('periodUnitLabel', () {
    test('유형별 단위', () {
      expect(SchedulePeriod.periodUnitLabel(ScheduleType.monthly), '개월');
      expect(SchedulePeriod.periodUnitLabel(ScheduleType.weekly), '주');
      expect(SchedulePeriod.periodUnitLabel(ScheduleType.yearly), '년');
    });
  });
}

/// 주인공 생일 기준 의미있는 성장 마일스톤(백일·돌·N살)을 계산한다 (아이디어10).
///
/// 같은 포즈로 쌓인 기록을 "백일", "첫 돌" 같은 시점에 자동으로 묶어 보여주기 위한
/// 순수 계산 모듈(데이터/위젯 의존 없음). 근처 사진 매칭은 UI 레이어에서 한다.
class Milestone {
  const Milestone({
    required this.label,
    required this.emoji,
    required this.date,
  });

  /// 표시 라벨(예: "백일", "첫 돌", "2살 생일").
  final String label;
  final String emoji;

  /// 마일스톤 날짜.
  final DateTime date;
}

class Milestones {
  const Milestones._();

  /// [birth] 기준 [now]까지 **이미 도달한** 마일스톤(과거→현재 순).
  ///
  /// 백일(생후 100일), 첫 돌(1년), 그리고 2살부터의 생일을 포함한다.
  static List<Milestone> reached(DateTime birth, DateTime now) {
    final b = DateTime(birth.year, birth.month, birth.day);
    final out = <Milestone>[
      Milestone(label: '백일', emoji: '🎉', date: b.add(const Duration(days: 100))),
      Milestone(label: '첫 돌', emoji: '🎂', date: DateTime(b.year + 1, b.month, b.day)),
    ];
    for (var y = 2; y <= 30; y++) {
      final d = DateTime(b.year + y, b.month, b.day);
      if (d.isAfter(now)) break;
      out.add(Milestone(label: '$y살 생일', emoji: '🎂', date: d));
    }
    final reachedOnly = out.where((m) => !m.date.isAfter(now)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return reachedOnly;
  }
}

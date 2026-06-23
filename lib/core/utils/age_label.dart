/// 생일과 촬영 시점으로 사람이 읽기 좋은 나이 라벨을 만든다 (아이디어1).
///
/// 예: 생후 18일 / 5개월 / 11개월 / 1살 / 3살 2개월.
/// 같은 포즈 사진에 나이를 얹어 "변화 체감"을 강화한다.
class AgeLabel {
  const AgeLabel._();

  /// [birth] 기준 [at] 시점의 나이 라벨. [at]가 출생 전이면 null.
  static String? format(DateTime birth, DateTime at) {
    final b = DateTime(birth.year, birth.month, birth.day);
    final d = DateTime(at.year, at.month, at.day);
    if (d.isBefore(b)) return null;

    var months = (d.year - b.year) * 12 + (d.month - b.month);
    if (d.day < b.day) months -= 1;
    if (months < 0) months = 0;

    if (months == 0) {
      final days = d.difference(b).inDays;
      return days <= 0 ? '태어난 날' : '생후 $days일';
    }
    if (months < 12) return '$months개월';

    final years = months ~/ 12;
    final remMonths = months % 12;
    return remMonths == 0 ? '$years살' : '$years살 $remMonths개월';
  }
}

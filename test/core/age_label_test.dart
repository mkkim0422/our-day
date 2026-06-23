import 'package:flutter_test/flutter_test.dart';
import 'package:our_day/core/utils/age_label.dart';

void main() {
  group('AgeLabel.format', () {
    final birth = DateTime(2024, 3, 10);

    test('태어난 날', () {
      expect(AgeLabel.format(birth, DateTime(2024, 3, 10)), '태어난 날');
    });

    test('생후 N일(첫 달)', () {
      expect(AgeLabel.format(birth, DateTime(2024, 3, 28)), '생후 18일');
    });

    test('개월(1년 미만)', () {
      expect(AgeLabel.format(birth, DateTime(2024, 8, 10)), '5개월');
      expect(AgeLabel.format(birth, DateTime(2025, 2, 10)), '11개월');
    });

    test('만 N살 / N살 M개월', () {
      expect(AgeLabel.format(birth, DateTime(2025, 3, 10)), '1살');
      expect(AgeLabel.format(birth, DateTime(2027, 5, 10)), '3살 2개월');
    });

    test('생일 지나기 전 날짜 보정(일 비교)', () {
      // 2025-03-09는 아직 1살 생일 하루 전 → 11개월.
      expect(AgeLabel.format(birth, DateTime(2025, 3, 9)), '11개월');
    });

    test('출생 전이면 null', () {
      expect(AgeLabel.format(birth, DateTime(2024, 3, 1)), isNull);
    });
  });
}

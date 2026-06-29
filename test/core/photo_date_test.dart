import 'package:flutter_test/flutter_test.dart';
import 'package:our_day/core/utils/photo_date.dart';

void main() {
  group('parseExifDateTime', () {
    test('표준 EXIF 형식(콜론 구분)을 파싱한다', () {
      expect(parseExifDateTime('2024:05:01 13:22:01'),
          DateTime(2024, 5, 1, 13, 22, 1));
    });

    test('하이픈·T 구분도 허용한다', () {
      expect(parseExifDateTime('2023-12-25T08:09:10'),
          DateTime(2023, 12, 25, 8, 9, 10));
    });

    test('앞뒤 공백을 무시한다', () {
      expect(parseExifDateTime('  2022:01:02 03:04:05  '),
          DateTime(2022, 1, 2, 3, 4, 5));
    });

    test('빈 EXIF 값(0000:00:00)은 null', () {
      expect(parseExifDateTime('0000:00:00 00:00:00'), isNull);
    });

    test('null·형식 불일치는 null', () {
      expect(parseExifDateTime(null), isNull);
      expect(parseExifDateTime('어제'), isNull);
      expect(parseExifDateTime('2024:13:40 99:99:99'), isNull); // 월 13
    });
  });
}

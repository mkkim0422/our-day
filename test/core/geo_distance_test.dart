import 'package:flutter_test/flutter_test.dart';
import 'package:our_day/core/utils/geo_distance.dart';

void main() {
  group('GeoDistance.haversineMeters', () {
    test('같은 좌표는 0', () {
      expect(GeoDistance.haversineMeters(37.5, 127.0, 37.5, 127.0), 0);
    });

    test('적도에서 경도 1도 ≈ 111.3km', () {
      final d = GeoDistance.haversineMeters(0, 0, 0, 1);
      expect(d, closeTo(111320, 500));
    });

    test('위도 1도 ≈ 111.2km (경도 무관)', () {
      final d = GeoDistance.haversineMeters(37, 127, 38, 127);
      expect(d, closeTo(111195, 500));
    });

    test('대칭성', () {
      final a = GeoDistance.haversineMeters(37.47, 126.59, 37.55, 126.97);
      final b = GeoDistance.haversineMeters(37.55, 126.97, 37.47, 126.59);
      expect(a, closeTo(b, 0.001));
    });
  });
}

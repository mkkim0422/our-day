import 'package:flutter_test/flutter_test.dart';
import 'package:our_day/data/db/app_database.dart';
import 'package:our_day/services/location/location_service.dart';
import 'package:our_day/services/location/place_recall.dart';

Place _place({
  required String id,
  required double lat,
  required double lng,
  int radiusM = 200,
  bool geofenceEnabled = true,
}) =>
    Place(
      id: id,
      projectId: 'pj',
      label: id,
      latitude: lat,
      longitude: lng,
      radiusM: radiusM,
      captureCount: 1,
      geofenceEnabled: geofenceEnabled,
    );

void main() {
  final now = DateTime(2026, 6, 23, 12);
  final here = const LocationPoint(37.5000, 127.0000);

  group('PlaceRecall.match', () {
    test('반경 안의 장소를 반환', () {
      // 약 11m 떨어진 지점(반경 200m 안).
      final p = _place(id: 'near', lat: 37.5001, lng: 127.0000);
      final result = PlaceRecall.match(
        here: here,
        places: [p],
        lastNotified: const {},
        now: now,
      );
      expect(result?.id, 'near');
    });

    test('반경 밖이면 null', () {
      // 약 1.1km 떨어진 지점(반경 200m 밖).
      final p = _place(id: 'far', lat: 37.5100, lng: 127.0000);
      final result = PlaceRecall.match(
        here: here,
        places: [p],
        lastNotified: const {},
        now: now,
      );
      expect(result, isNull);
    });

    test('지오펜스가 꺼진 장소는 제외', () {
      final p = _place(id: 'off', lat: 37.5001, lng: 127.0, geofenceEnabled: false);
      expect(
        PlaceRecall.match(
            here: here, places: [p], lastNotified: const {}, now: now),
        isNull,
      );
    });

    test('쿨다운 내면 알림하지 않음', () {
      final p = _place(id: 'recent', lat: 37.5001, lng: 127.0);
      final result = PlaceRecall.match(
        here: here,
        places: [p],
        lastNotified: {'recent': now.subtract(const Duration(hours: 1))},
        now: now,
        cooldown: const Duration(hours: 6),
      );
      expect(result, isNull);
    });

    test('쿨다운이 지나면 다시 알림', () {
      final p = _place(id: 'old', lat: 37.5001, lng: 127.0);
      final result = PlaceRecall.match(
        here: here,
        places: [p],
        lastNotified: {'old': now.subtract(const Duration(hours: 7))},
        now: now,
        cooldown: const Duration(hours: 6),
      );
      expect(result?.id, 'old');
    });

    test('여러 후보 중 가장 가까운 장소', () {
      final near = _place(id: 'near', lat: 37.50005, lng: 127.0);
      final mid = _place(id: 'mid', lat: 37.5001, lng: 127.0);
      final result = PlaceRecall.match(
        here: here,
        places: [mid, near],
        lastNotified: const {},
        now: now,
      );
      expect(result?.id, 'near');
    });
  });
}

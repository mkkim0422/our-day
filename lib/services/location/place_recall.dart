import '../../core/utils/geo_distance.dart';
import '../../data/db/app_database.dart';
import 'location_service.dart';

/// 위치 기반 회상 알림의 **판정 로직** (5장). 외부 의존 없는 순수 함수 → 테스트 용이.
///
/// 배경 지오펜스든 전경 근접 체크든, "지금 위치에서 어떤 장소의 추억을 띄울지"는
/// 모두 이 로직으로 결정한다.
class PlaceRecall {
  const PlaceRecall._();

  /// 기본 알림 쿨다운 — 같은 장소에서 과도한 반복 알림 방지(5장 빈도 제한).
  static const defaultCooldown = Duration(hours: 6);

  /// [here]에서 **지오펜스 반경 안**에 든 장소 중, 쿨다운이 지났고 가장 가까운 곳.
  /// 없으면 null.
  static Place? match({
    required LocationPoint here,
    required List<Place> places,
    required Map<String, DateTime> lastNotified,
    required DateTime now,
    Duration cooldown = defaultCooldown,
  }) {
    Place? best;
    var bestDist = double.infinity;
    for (final place in places) {
      if (!place.geofenceEnabled) continue;
      final dist = GeoDistance.haversineMeters(
        here.latitude,
        here.longitude,
        place.latitude,
        place.longitude,
      );
      if (dist > place.radiusM) continue; // 반경 밖.

      final last = lastNotified[place.id];
      if (last != null && now.difference(last) < cooldown) continue; // 빈도 제한.

      if (dist < bestDist) {
        best = place;
        bestDist = dist;
      }
    }
    return best;
  }
}

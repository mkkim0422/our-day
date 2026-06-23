import 'dart:math' as math;

/// 좌표 간 거리 계산 (5장 위치 기반 회상 알림).
///
/// 지오펜스 반경 판정·근접 장소 탐색에 쓰인다. 외부 의존 없는 순수 계산이라
/// 단위 테스트가 쉽고, 전경 근접 체크와 (후속) 배경 지오펜스가 함께 재사용한다.
class GeoDistance {
  const GeoDistance._();

  /// 두 위경도 사이의 대권 거리(m) — Haversine.
  static double haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthR = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthR * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double deg) => deg * math.pi / 180.0;
}

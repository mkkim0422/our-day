import 'package:geolocator/geolocator.dart';

/// 위경도 한 점.
class LocationPoint {
  const LocationPoint(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

/// 위치 서비스 추상화 (5장). 플랫폼 의존(geolocator)을 이 뒤로 격리(8장).
///
/// 회상 알림은 **전경 근접 체크**로 동작하므로 전경 권한(whileInUse)이면 충분하다.
/// "항상 허용"(백그라운드)을 강요하지 않는다(5장 — 민감도·심사 우려). 배경 지오펜스를
/// 붙일 때만 always 권한을 별도로, opt-in으로 요청한다.
abstract interface class LocationService {
  /// 위치 서비스 켜짐 + 권한 확보(필요 시 요청). 성공 시 true.
  Future<bool> ensurePermission();

  /// 현재 위치 1회 조회. 권한/서비스 없거나 실패 시 null.
  Future<LocationPoint?> current();
}

/// geolocator 기반 구현.
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  @override
  Future<LocationPoint?> current() async {
    if (!await ensurePermission()) return null;
    try {
      final pos = await Geolocator.getCurrentPosition();
      return LocationPoint(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }
}

import 'package:geolocator/geolocator.dart';

/// 위경도 한 점.
class LocationPoint {
  const LocationPoint(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

/// 위치 권한 요청 결과(5장 — 회복 가능한 권한 UX).
enum LocationAuth {
  granted,

  /// 이번엔 거부(다시 물어볼 수 있음).
  denied,

  /// 영구 거부 — 앱 설정에서만 켤 수 있음(설정 화면으로 안내 필요).
  deniedForever,

  /// 기기 위치 서비스 자체가 꺼짐.
  serviceOff,
}

/// 위치 서비스 추상화 (5장). 플랫폼 의존(geolocator)을 이 뒤로 격리(8장).
///
/// 회상 알림은 **전경 근접 체크**로 동작하므로 전경 권한(whileInUse)이면 충분하다.
/// "항상 허용"(백그라운드)을 강요하지 않는다(5장 — 민감도·심사 우려). 배경 지오펜스를
/// 붙일 때만 always 권한을 별도로, opt-in으로 요청한다.
abstract interface class LocationService {
  /// 위치 권한을 요청하고 상세 결과를 반환(설정으로 안내할지 판단용).
  Future<LocationAuth> requestPermission();

  /// 위치 서비스 켜짐 + 권한 확보. 성공 시 true(내부 편의용).
  Future<bool> ensurePermission();

  /// 현재 위치 1회 조회. 권한/서비스 없거나 실패 시 null.
  Future<LocationPoint?> current();

  /// 기기의 앱 설정 화면 열기(영구 거부 회복용).
  Future<void> openSettings();
}

/// geolocator 기반 구현.
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<LocationAuth> requestPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAuth.serviceOff;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationAuth.granted;
      case LocationPermission.deniedForever:
        return LocationAuth.deniedForever;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationAuth.denied;
    }
  }

  @override
  Future<bool> ensurePermission() async =>
      (await requestPermission()) == LocationAuth.granted;

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

  @override
  Future<void> openSettings() => Geolocator.openAppSettings();
}

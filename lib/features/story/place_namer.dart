import 'package:geocoding/geocoding.dart';

/// GPS 좌표 → 지역명(역지오코딩, OS 내장·무료).
///
/// 같은 좌표를 반복 조회하지 않도록 캐시한다. 지역(동/시/도/국가) 이름까지만
/// 얻을 수 있고, "○○해수욕장" 같은 정확한 명소명은 유료 Places API가 필요하다.
/// 기기에 지오코더 백엔드가 없거나 실패하면 null(호출 측이 '여행'으로 폴백).
class PlaceNamer {
  final _cache = <String, String?>{};

  Future<String?> nameFor(double lat, double lng) async {
    // 소수 2자리(~1km)로 묶어 캐시 — 같은 동네는 한 번만 조회.
    final key = '${lat.toStringAsFixed(2)},${lng.toStringAsFixed(2)}';
    if (_cache.containsKey(key)) return _cache[key];

    String? name;
    try {
      final marks = await placemarkFromCoordinates(lat, lng);
      if (marks.isNotEmpty) name = _best(marks.first);
    } catch (_) {
      // 지오코더 미지원·네트워크 실패 등은 이름 없음으로.
    }
    _cache[key] = name;
    return name;
  }

  /// 가장 구체적이고 의미 있는 이름 우선(동 → 시 → 도/주 → 국가).
  String? _best(Placemark m) {
    for (final c in [
      m.subLocality,
      m.locality,
      m.administrativeArea,
      m.country,
    ]) {
      final v = c?.trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }
}

/// 위치명 + 여행 길이로 제목을 만든다(뒤 문구를 여러 패턴으로).
/// 이름이 없으면 그냥 '여행'.
String tripTitle(String? place, {required int days}) {
  if (place == null || place.isEmpty) return '여행';
  // 며칠 머문 여행 vs 하루 다녀온 곳을 다른 말투로.
  return days >= 2 ? '$place 여행' : '$place에서의 추억';
}

import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';

/// 장소(Place) 접근. 위치 기반 회상 알림(5장)의 지오펜스 기준.
class PlaceRepository {
  PlaceRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Stream<List<Place>> watchByProject(String projectId) {
    final q = _db.select(_db.places)
      ..where((p) => p.projectId.equals(projectId))
      ..orderBy([(p) => OrderingTerm.desc(p.captureCount)]);
    return q.watch();
  }

  /// 지오펜스 등록 우선순위: capture_count 높은 장소 우선(5장 — 플랫폼 한도 대응).
  Future<List<Place>> topByCaptureCount(int limit) {
    final q = _db.select(_db.places)
      ..where((p) => p.geofenceEnabled.equals(true))
      ..orderBy([(p) => OrderingTerm.desc(p.captureCount)])
      ..limit(limit);
    return q.get();
  }

  /// 좌표 근처(반경 내)에 이미 등록된 장소를 찾는다. 없으면 null.
  /// 같은 장소 재촬영 시 새 Place를 만들지 않고 기존 것을 재사용하기 위함.
  Future<Place?> findNear(
    String projectId,
    double lat,
    double lng, {
    double toleranceM = 150,
  }) async {
    final places = await (_db.select(_db.places)
          ..where((p) => p.projectId.equals(projectId)))
        .get();
    Place? best;
    double bestDist = double.infinity;
    for (final p in places) {
      final d = _haversineMeters(lat, lng, p.latitude, p.longitude);
      if (d <= toleranceM && d < bestDist) {
        best = p;
        bestDist = d;
      }
    }
    return best;
  }

  Future<Place> create({
    required String projectId,
    required String label,
    required double latitude,
    required double longitude,
    int radiusM = 200,
  }) async {
    final id = _uuid.v4();
    await _db.into(_db.places).insert(
          PlacesCompanion.insert(
            id: id,
            projectId: projectId,
            label: label,
            latitude: latitude,
            longitude: longitude,
            radiusM: Value(radiusM),
            captureCount: const Value(1),
          ),
        );
    return (_db.select(_db.places)..where((p) => p.id.equals(id)))
        .getSingle();
  }

  Future<void> incrementCaptureCount(String id) {
    return _db.customUpdate(
      'UPDATE places SET capture_count = capture_count + 1 WHERE id = ?',
      variables: [Variable.withString(id)],
      updates: {_db.places},
    );
  }

  Future<void> setGeofenceEnabled(String id, bool enabled) {
    return (_db.update(_db.places)..where((p) => p.id.equals(id)))
        .write(PlacesCompanion(geofenceEnabled: Value(enabled)));
  }

  /// 두 좌표 간 거리(m) — Haversine.
  static double _haversineMeters(
      double lat1, double lon1, double lat2, double lon2) {
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

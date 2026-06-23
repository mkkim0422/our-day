import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:our_day/core/constants/enums.dart';
import 'package:our_day/data/db/app_database.dart';
import 'package:our_day/data/repositories/place_repository.dart';
import 'package:our_day/data/repositories/project_repository.dart';

void main() {
  late AppDatabase db;
  late PlaceRepository places;
  late String projectId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    places = PlaceRepository(db);
    final project = await ProjectRepository(db)
        .create(title: 'p', scheduleType: ScheduleType.manual);
    projectId = project.id;
  });

  tearDown(() => db.close());

  Future<String> addPlace(String label, double lat, int count) async {
    final p = await places.create(
      projectId: projectId,
      label: label,
      latitude: lat,
      longitude: 127.0,
    );
    for (var i = 1; i < count; i++) {
      await places.incrementCaptureCount(p.id);
    }
    return p.id;
  }

  test('enforceGeofenceLimit: capture_count 상위 N개만 지오펜스 활성', () async {
    // 서로 충분히 떨어진 좌표(중복 병합 방지) + 서로 다른 촬영 수.
    await addPlace('A', 37.10, 5);
    await addPlace('B', 37.20, 3);
    await addPlace('C', 37.30, 1);

    await places.enforceGeofenceLimit(projectId, maxEnabled: 2);

    final all = await places.watchByProject(projectId).first; // capture_count desc
    expect(all.map((p) => p.label).toList(), ['A', 'B', 'C']);
    expect(all[0].geofenceEnabled, isTrue); // A(5)
    expect(all[1].geofenceEnabled, isTrue); // B(3)
    expect(all[2].geofenceEnabled, isFalse); // C(1) — 한도 밖
  });

  test('findNear: 장소 radiusM 기준으로 같은 장소를 재사용', () async {
    final id = await addPlace('월미도', 37.4753, 1);
    // 약 44m 떨어진 좌표 → 같은 장소(기본 반경 200m 안).
    final near = await places.findNear(projectId, 37.4757, 127.0);
    expect(near?.id, id);
    // 약 11km → 다른 장소.
    final far = await places.findNear(projectId, 37.5753, 127.0);
    expect(far, isNull);
  });
}

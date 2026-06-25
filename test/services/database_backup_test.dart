import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:our_day/core/constants/enums.dart';
import 'package:our_day/data/db/app_database.dart';
import 'package:our_day/data/repositories/account_repository.dart';
import 'package:our_day/data/repositories/capture_repository.dart';
import 'package:our_day/data/repositories/place_repository.dart';
import 'package:our_day/data/repositories/project_repository.dart';
import 'package:our_day/services/backup/database_backup.dart';
import 'package:path/path.dart' as p;

void main() {
  late AppDatabase source;
  late AppDatabase target;

  setUp(() {
    source = AppDatabase.forTesting(NativeDatabase.memory());
    target = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  Future<void> seed(AppDatabase db) async {
    await AccountRepository(db).upsert(
      id: 'uid-1',
      provider: AccountProvider.google,
      displayName: '엄마',
    );
    final project = await ProjectRepository(db).create(
      title: '우리 가족',
      scheduleType: ScheduleType.monthly,
      scheduleConfig: {'day': 1},
      eventPegs: {EventPeg.birthday},
    );
    final place = await PlaceRepository(db).create(
      projectId: project.id,
      label: '월미도',
      latitude: 37.47,
      longitude: 126.59,
    );
    await CaptureRepository(db).create(
      project: project,
      filePath: '/orig/captures/photo-1.jpg',
      thumbPath: '/orig/thumbs/photo-1.jpg',
      capturedAt: DateTime(2026, 6, 1, 10),
      alignmentMeta: {'dx': 0.1, 'scale': 1.2},
      note: '첫 컷',
      placeId: place.id,
    );
  }

  test('export → import 라운드트립: 행 수·필드·경로 재구성', () async {
    await seed(source);

    final manifest = await DatabaseBackup(source).exportManifest(
      now: DateTime(2026, 6, 23, 12),
    );
    expect(manifest['version'], DatabaseBackup.formatVersion);
    expect((manifest['captures'] as List), hasLength(1));

    final restored = await DatabaseBackup(target).importManifest(
      manifest,
      capturesDir: '/new/captures',
      thumbsDir: '/new/thumbs',
    );
    expect(restored, 1);

    final account = await AccountRepository(target).current();
    expect(account?.displayName, '엄마');
    expect(account?.provider, AccountProvider.google);

    final projects = await ProjectRepository(target).watchAll().first;
    expect(projects, hasLength(1));
    expect(projects.first.scheduleType, ScheduleType.monthly);
    expect(projects.first.scheduleConfig['day'], 1);
    expect(projects.first.eventPeg, EventPeg.birthday);

    final captures =
        await CaptureRepository(target).listByProject(projects.first.id);
    expect(captures, hasLength(1));
    final c = captures.first;
    // 경로는 새 기기 디렉터리 기준으로 재구성(파일명만 보존).
    // 구분자는 플랫폼별로 다르므로 p.join으로 비교(Windows=\, POSIX=/).
    expect(c.filePath, p.join('/new/captures', 'photo-1.jpg'));
    expect(c.thumbPath, p.join('/new/thumbs', 'photo-1.jpg'));
    expect(c.note, '첫 컷');
    expect(c.placeId, isNotNull);
    expect(c.alignmentMeta?['scale'], 1.2);
    expect(c.capturedAt, DateTime(2026, 6, 1, 10));

    final places = await PlaceRepository(target).watchByProject(projects.first.id).first;
    expect(places.single.label, '월미도');
  });

  test('replace 복원은 기존 데이터를 교체한다', () async {
    // target에 다른 데이터를 먼저 넣어 둔다.
    await ProjectRepository(target).create(
      title: '버려질 프로젝트',
      scheduleType: ScheduleType.yearly,
    );

    await seed(source);
    final manifest = await DatabaseBackup(source).exportManifest();
    await DatabaseBackup(target).importManifest(
      manifest,
      capturesDir: '/new/captures',
      thumbsDir: '/new/thumbs',
    );

    final projects = await ProjectRepository(target).watchAll().first;
    expect(projects, hasLength(1));
    expect(projects.first.title, '우리 가족');
  });

  test('빈 DB도 안전하게 export/import 된다', () async {
    final manifest = await DatabaseBackup(source).exportManifest();
    expect(manifest['account'], isNull);
    expect(manifest['projects'], isEmpty);

    final restored = await DatabaseBackup(target).importManifest(
      manifest,
      capturesDir: '/c',
      thumbsDir: '/t',
    );
    expect(restored, 0);
  });
}

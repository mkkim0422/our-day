import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:our_day/core/constants/enums.dart';
import 'package:our_day/data/db/app_database.dart';
import 'package:our_day/data/repositories/account_repository.dart';
import 'package:our_day/data/repositories/capture_repository.dart';
import 'package:our_day/data/repositories/place_repository.dart';
import 'package:our_day/data/repositories/project_repository.dart';

void main() {
  late AppDatabase db;
  late ProjectRepository projects;
  late CaptureRepository captures;
  late PlaceRepository places;
  late AccountRepository accounts;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    projects = ProjectRepository(db);
    captures = CaptureRepository(db);
    places = PlaceRepository(db);
    accounts = AccountRepository(db);
  });

  tearDown(() => db.close());

  test('프로젝트 생성 + uuid 발급', () async {
    final p = await projects.create(
      title: '우리 가족',
      scheduleType: ScheduleType.monthly,
      scheduleConfig: {'day': 1},
      eventPeg: EventPeg.birthday,
    );
    expect(p.id, isNotEmpty);
    expect(p.title, '우리 가족');
    expect(p.scheduleConfig['day'], 1);
    expect(p.eventPeg, EventPeg.birthday);
  });

  test('Capture 저장 시 월간 period_label 자동 계산', () async {
    final p = await projects.create(
      title: 'p',
      scheduleType: ScheduleType.monthly,
    );
    final c = await captures.create(
      project: p,
      filePath: '/x/orig.jpg',
      thumbPath: '/x/thumb.jpg',
      capturedAt: DateTime(2026, 6, 23),
    );
    expect(c.periodLabel, '2026 · 6월');
    expect(await captures.countByProject(p.id), 1);
    expect(c.backupState, BackupState.localOnly);
  });

  test('이번 기간 중복 촬영 판정(월간)', () async {
    final p = await projects.create(
      title: 'p',
      scheduleType: ScheduleType.monthly,
    );
    expect(
      await captures.hasCaptureInCurrentPeriod(p, DateTime(2026, 6, 23)),
      isFalse,
    );
    await captures.create(
      project: p,
      filePath: '/a.jpg',
      thumbPath: '/a_t.jpg',
      capturedAt: DateTime(2026, 6, 10),
    );
    // 같은 달 → 이미 찍음
    expect(
      await captures.hasCaptureInCurrentPeriod(p, DateTime(2026, 6, 23)),
      isTrue,
    );
    // 다른 달 → 아직 안 찍음
    expect(
      await captures.hasCaptureInCurrentPeriod(p, DateTime(2026, 7, 1)),
      isFalse,
    );
  });

  test('FK cascade: 프로젝트 삭제 시 Capture도 삭제', () async {
    final p = await projects.create(title: 'p', scheduleType: ScheduleType.manual);
    await captures.create(
      project: p,
      filePath: '/a.jpg',
      thumbPath: '/a_t.jpg',
      capturedAt: DateTime(2026, 6, 23),
    );
    await projects.delete(p.id);
    expect(await captures.countByProject(p.id), 0);
  });

  test('Place 근접 탐색(findNear) — 반경 내 기존 장소 재사용', () async {
    final p = await projects.create(title: 'p', scheduleType: ScheduleType.manual);
    final created = await places.create(
      projectId: p.id,
      label: '월미도',
      latitude: 37.4753,
      longitude: 126.5965,
    );
    // 약 50m 떨어진 좌표 → 같은 장소로 탐지
    final near = await places.findNear(p.id, 37.4757, 126.5965);
    expect(near?.id, created.id);
    // 멀리 떨어진 좌표(서울시청) → 없음
    final far = await places.findNear(p.id, 37.5663, 126.9779);
    expect(far, isNull);
  });

  test('Account upsert + 백업 대상 설정', () async {
    await accounts.upsert(
      id: 'uid-1',
      provider: AccountProvider.google,
      displayName: '홍길동',
    );
    await accounts.setBackupTarget('uid-1', BackupTarget.googleDrive);
    final acc = await accounts.current();
    expect(acc?.displayName, '홍길동');
    expect(acc?.backupTarget, BackupTarget.googleDrive);
  });
}

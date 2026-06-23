import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:our_day/core/constants/enums.dart';
import 'package:our_day/data/db/app_database.dart';
import 'package:our_day/data/repositories/capture_repository.dart';
import 'package:our_day/data/repositories/member_repository.dart';
import 'package:our_day/data/repositories/project_repository.dart';

void main() {
  late AppDatabase db;
  late MemberRepository members;
  late ProjectRepository projects;
  late CaptureRepository captures;
  late Project project;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    members = MemberRepository(db);
    projects = ProjectRepository(db);
    captures = CaptureRepository(db);
    project =
        await projects.create(title: '우리 가족', scheduleType: ScheduleType.monthly);
  });

  tearDown(() => db.close());

  Future<String> addCapture(String label) async {
    final c = await captures.create(
      project: project,
      filePath: '/c/$label.jpg',
      thumbPath: '/t/$label.jpg',
      capturedAt: DateTime(2026, 6, 1),
    );
    return c.id;
  }

  test('구성원 생성·조회·삭제', () async {
    final mom = await members.create(projectId: project.id, name: '엄마', role: '엄마');
    final kid = await members.create(projectId: project.id, name: '첫째');
    final list = await members.listByProject(project.id);
    expect(list.map((m) => m.name).toList(), ['엄마', '첫째']); // 이름 오름차순

    await members.delete(mom.id);
    final after = await members.listByProject(project.id);
    expect(after.single.id, kid.id);
  });

  test('촬영 태깅 교체 + 구성원별 촬영 조회', () async {
    final mom = await members.create(projectId: project.id, name: '엄마');
    final kid = await members.create(projectId: project.id, name: '첫째');
    final c1 = await addCapture('c1');
    final c2 = await addCapture('c2');

    await members.setMembersForCapture(c1, [mom.id, kid.id]);
    await members.setMembersForCapture(c2, [kid.id]);

    expect((await members.memberIdsForCapture(c1)).toSet(), {mom.id, kid.id});
    expect(await members.captureIdsForMember(kid.id), {c1, c2});
    expect(await members.captureIdsForMember(mom.id), {c1});

    // 교체: c1을 엄마만으로.
    await members.setMembersForCapture(c1, [mom.id]);
    expect(await members.memberIdsForCapture(c1), [mom.id]);
    expect(await members.captureIdsForMember(kid.id), {c2});
  });

  test('구성원 삭제 시 태그도 정리(FK cascade)', () async {
    final kid = await members.create(projectId: project.id, name: '첫째');
    final c1 = await addCapture('c1');
    await members.setMembersForCapture(c1, [kid.id]);

    await members.delete(kid.id);
    expect(await members.memberIdsForCapture(c1), isEmpty);
  });
}

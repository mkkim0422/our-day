import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:our_day/core/constants/enums.dart';
import 'package:our_day/data/db/app_database.dart';
import 'package:our_day/data/repositories/capture_repository.dart';
import 'package:our_day/data/repositories/member_repository.dart';
import 'package:our_day/data/repositories/place_repository.dart';
import 'package:our_day/data/repositories/project_repository.dart';
import 'package:our_day/services/backup/local_backup_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);
  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late AppDatabase db;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('backup_test');
    PathProviderPlatform.instance = _FakePathProvider(temp.path);
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  final photoBytes = Uint8List.fromList(List.generate(64, (i) => i % 256));

  Future<String> seedCaptureWithFiles() async {
    final capturesDir = Directory(p.join(temp.path, 'captures'))
      ..createSync(recursive: true);
    final thumbsDir = Directory(p.join(temp.path, 'thumbs'))
      ..createSync(recursive: true);
    final photoPath = p.join(capturesDir.path, 'photo-1.jpg');
    final thumbPath = p.join(thumbsDir.path, 'photo-1.jpg');
    File(photoPath).writeAsBytesSync(photoBytes);
    File(thumbPath).writeAsBytesSync(photoBytes);

    final project = await ProjectRepository(db).create(
      title: '우리 가족',
      scheduleType: ScheduleType.monthly,
    );
    await CaptureRepository(db).create(
      project: project,
      filePath: photoPath,
      thumbPath: thumbPath,
      capturedAt: DateTime(2026, 6, 1),
    );
    return photoPath;
  }

  test('createBackup: manifest+사진을 zip으로 묶는다', () async {
    await seedCaptureWithFiles();

    final zipPath = await LocalBackupService(db).createBackup(
      now: DateTime(2026, 6, 23, 12),
    );

    expect(File(zipPath).existsSync(), isTrue);
    final archive = ZipDecoder().decodeBytes(File(zipPath).readAsBytesSync());
    final names = archive.files.map((f) => f.name).toList();
    expect(names, contains('manifest.json'));
    expect(names, contains('photos/photo-1.jpg'));
    expect(names, contains('thumbs/photo-1.jpg'));
  });

  test('restoreFromFile: 사진과 DB를 되살린다', () async {
    final photoPath = await seedCaptureWithFiles();
    final service = LocalBackupService(db);
    final zipPath = await service.createBackup();

    // 사진과 DB를 비운다(기기 변경 흉내).
    File(photoPath).deleteSync();
    await ProjectRepository(db).delete(
      (await ProjectRepository(db).watchAll().first).first.id,
    );
    expect(await CaptureRepository(db).countByProject('any'), 0);

    final restored = await service.restoreFromFile(zipPath);
    expect(restored, 1);

    // 사진 파일이 같은 바이트로 복구됐는지.
    expect(File(photoPath).existsSync(), isTrue);
    expect(File(photoPath).readAsBytesSync(), photoBytes);

    // DB의 Capture도 되살아났는지.
    final projects = await ProjectRepository(db).watchAll().first;
    expect(projects, hasLength(1));
    final captures =
        await CaptureRepository(db).listByProject(projects.first.id);
    expect(captures, hasLength(1));
    expect(captures.first.filePath, photoPath);
  });

  test('누수 없음: 구성원·태그·꾸민사진·정렬순서·설정까지 모두 복원된다', () async {
    // 사진 + 꾸민사진 + 설정 파일을 모두 심는다.
    final capturesDir = Directory(p.join(temp.path, 'captures'))
      ..createSync(recursive: true);
    final thumbsDir = Directory(p.join(temp.path, 'thumbs'))
      ..createSync(recursive: true);
    final exportsDir = Directory(p.join(temp.path, 'exports'))
      ..createSync(recursive: true);
    final photoPath = p.join(capturesDir.path, 'photo-1.jpg');
    final thumbPath = p.join(thumbsDir.path, 'photo-1.jpg');
    final decoPath = p.join(exportsDir.path, 'deco-1.png');
    final decoBytes = Uint8List.fromList(List.generate(40, (i) => (i * 3) % 256));
    File(photoPath).writeAsBytesSync(photoBytes);
    File(thumbPath).writeAsBytesSync(photoBytes);
    File(decoPath).writeAsBytesSync(decoBytes);

    final project = await ProjectRepository(db).create(
      title: '우리 가족',
      scheduleType: ScheduleType.monthly,
    );
    final captureRepo = CaptureRepository(db);
    final capture = await captureRepo.create(
      project: project,
      filePath: photoPath,
      thumbPath: thumbPath,
      capturedAt: DateTime(2026, 6, 1),
    );
    // 구성원 + 태그 + 꾸민사진 + 정렬순서.
    final memberRepo = MemberRepository(db);
    final mom = await memberRepo.create(projectId: project.id, name: '엄마', role: '엄마');
    await memberRepo.setMembersForCapture(capture.id, [mom.id]);
    await captureRepo.setDecoratedPath(capture.id, decoPath);
    await captureRepo.reorder([capture.id]); // sortIndex = 0

    // 설정 파일(생일·키·앱잠금).
    final settingsPath = p.join(temp.path, 'settings.json');
    File(settingsPath).writeAsStringSync(jsonEncode({
      'projectBirthdays': {project.id: '2025-03-15T00:00:00.000'},
      'captureHeights': {capture.id: 92.5},
      'lockPinHash': 'deadbeef',
    }));

    final service = LocalBackupService(db);
    final zipPath = await service.createBackup();

    // zip에 꾸민사진이 들어갔는지.
    final names = ZipDecoder()
        .decodeBytes(File(zipPath).readAsBytesSync())
        .files
        .map((f) => f.name)
        .toList();
    expect(names, contains('decorated/deco-1.png'));

    // 기기 변경 흉내: DB·사진·꾸민사진·설정 모두 삭제.
    File(photoPath).deleteSync();
    File(decoPath).deleteSync();
    File(settingsPath).deleteSync();
    await ProjectRepository(db).delete(project.id);

    final restored = await service.restoreFromFile(zipPath);
    expect(restored, 1);

    // 1) 사진·꾸민사진 파일 복구.
    expect(File(photoPath).existsSync(), isTrue);
    expect(File(decoPath).existsSync(), isTrue);
    expect(File(decoPath).readAsBytesSync(), decoBytes);

    // 2) Capture의 꾸민사진 경로·정렬순서 복구.
    final caps = await captureRepo.listByProject(project.id);
    expect(caps, hasLength(1));
    expect(caps.first.decoratedPath, decoPath);
    expect(caps.first.sortIndex, 0);

    // 3) 구성원 + 태그 복구.
    final members = await memberRepo.listByProject(project.id);
    expect(members.map((m) => m.name), contains('엄마'));
    final tagged = await memberRepo.memberIdsForCapture(capture.id);
    expect(tagged, contains(mom.id));

    // 4) 설정(settings.json) 복구.
    expect(File(settingsPath).existsSync(), isTrue);
    final settings =
        jsonDecode(File(settingsPath).readAsStringSync()) as Map<String, dynamic>;
    expect((settings['projectBirthdays'] as Map)[project.id],
        '2025-03-15T00:00:00.000');
    expect((settings['captureHeights'] as Map)[capture.id], 92.5);
    expect(settings['lockPinHash'], 'deadbeef');
  });

  test('복원 후 기능별 조회 경로가 정상 동작한다(다중 프로젝트·정렬·필터·장소·설정)',
      () async {
    final capturesDir = Directory(p.join(temp.path, 'captures'))
      ..createSync(recursive: true);
    final thumbsDir = Directory(p.join(temp.path, 'thumbs'))
      ..createSync(recursive: true);
    final exportsDir = Directory(p.join(temp.path, 'exports'))
      ..createSync(recursive: true);

    final projectRepo = ProjectRepository(db);
    final captureRepo = CaptureRepository(db);
    final memberRepo = MemberRepository(db);
    final placeRepo = PlaceRepository(db);

    Future<Capture> mkCapture(Project pj, String name, DateTime at,
        {String? placeId}) async {
      final photo = p.join(capturesDir.path, '$name.jpg');
      final thumb = p.join(thumbsDir.path, '$name.jpg');
      File(photo).writeAsBytesSync(photoBytes);
      File(thumb).writeAsBytesSync(photoBytes);
      return captureRepo.create(
        project: pj,
        filePath: photo,
        thumbPath: thumb,
        capturedAt: at,
        placeId: placeId,
      );
    }

    // 프로젝트 A: 장소·구성원·꾸민사진·사용자 정렬·키·생일.
    final a =
        await projectRepo.create(title: '첫째', scheduleType: ScheduleType.monthly);
    final place = await placeRepo.create(
        projectId: a.id, label: '할머니집', latitude: 37.5, longitude: 127.0);
    final a1 = await mkCapture(a, 'a1', DateTime(2026, 1, 1), placeId: place.id);
    final a2 = await mkCapture(a, 'a2', DateTime(2026, 2, 1));
    final a3 = await mkCapture(a, 'a3', DateTime(2026, 3, 1));
    // 사용자가 촬영일순과 다르게 직접 배치: a3, a1, a2.
    await captureRepo.reorder([a3.id, a1.id, a2.id]);
    final mom = await memberRepo.create(projectId: a.id, name: '엄마');
    await memberRepo.setMembersForCapture(a2.id, [mom.id]);
    final deco = p.join(exportsDir.path, 'a3-deco.png');
    final decoBytes = Uint8List.fromList(List.generate(30, (i) => (i * 7) % 256));
    File(deco).writeAsBytesSync(decoBytes);
    await captureRepo.setDecoratedPath(a3.id, deco);

    // 프로젝트 B(격리 확인).
    final b =
        await projectRepo.create(title: '여행', scheduleType: ScheduleType.yearly);
    final b1 = await mkCapture(b, 'b1', DateTime(2025, 7, 7));

    final settingsPath = p.join(temp.path, 'settings.json');
    File(settingsPath).writeAsStringSync(jsonEncode({
      'locationRecallEnabled': true,
      'placeLastNotified': {place.id: '2026-03-02T09:00:00.000'},
      'projectBirthdays': {a.id: '2025-12-01T00:00:00.000'},
      'captureHeights': {a1.id: 70.0, a3.id: 80.5},
      'lockPinHash': 'pinhash123',
    }));

    final service = LocalBackupService(db);
    final zip = await service.createBackup();

    // === 공장 초기화 흉내: 파일·설정·DB 전부 삭제 ===
    for (final f in capturesDir.listSync()) {
      f.deleteSync();
    }
    for (final f in exportsDir.listSync()) {
      f.deleteSync();
    }
    File(settingsPath).deleteSync();
    await projectRepo.delete(a.id);
    await projectRepo.delete(b.id);
    expect(await projectRepo.watchAll().first, isEmpty);

    // === 복원 ===
    final restored = await service.restoreFromFile(zip);
    expect(restored, 4);

    // 1) 다중 프로젝트 복원.
    final projects = await projectRepo.watchAll().first;
    expect(projects.map((e) => e.title).toSet(), {'첫째', '여행'});

    // 2) 타임라인/타임랩스 정렬(watchByProject) = 사용자가 정한 순서.
    final aCaps = await captureRepo.watchByProject(a.id).first;
    expect(aCaps.map((c) => c.id).toList(), [a3.id, a1.id, a2.id]);

    // 3) 모든 사진 파일 복구(비교·타임랩스가 파일을 읽음).
    for (final c in aCaps) {
      expect(File(c.filePath).existsSync(), isTrue);
    }

    // 4) 구성원 필터(captureIdsForMember) = a2만.
    expect(await memberRepo.captureIdsForMember(mom.id), {a2.id});

    // 5) 장소 복구 + capture의 placeId(위치 회상 경로).
    final places = await placeRepo.watchByProject(a.id).first;
    expect(places.single.label, '할머니집');
    expect((await captureRepo.getById(a1.id))?.placeId, place.id);

    // 6) 꾸민사진 경로·파일 복구(상세에서 꾸민 버전 표시).
    final a3r = await captureRepo.getById(a3.id);
    expect(a3r?.decoratedPath, deco);
    expect(File(deco).existsSync(), isTrue);

    // 7) 설정 복구(나이라벨·마일스톤·성장차트·앱잠금·위치회상).
    final settings =
        jsonDecode(File(settingsPath).readAsStringSync()) as Map<String, dynamic>;
    expect(settings['locationRecallEnabled'], true);
    expect((settings['projectBirthdays'] as Map)[a.id], '2025-12-01T00:00:00.000');
    expect((settings['captureHeights'] as Map)[a3.id], 80.5);
    expect((settings['placeLastNotified'] as Map)[place.id],
        '2026-03-02T09:00:00.000');
    expect(settings['lockPinHash'], 'pinhash123');

    // 8) 프로젝트 B 격리(섞이지 않음).
    final bCaps = await captureRepo.watchByProject(b.id).first;
    expect(bCaps.map((c) => c.id).toList(), [b1.id]);
  });
}

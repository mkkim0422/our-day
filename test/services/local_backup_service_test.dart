import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:our_day/core/constants/enums.dart';
import 'package:our_day/data/db/app_database.dart';
import 'package:our_day/data/repositories/capture_repository.dart';
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
}

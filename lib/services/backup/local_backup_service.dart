import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/db/app_database.dart';
import 'database_backup.dart';

/// 로컬 백업 파일(.zip) 1건의 요약 정보.
class BackupFileInfo {
  const BackupFileInfo({
    required this.path,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  final String path;
  final int sizeBytes;
  final DateTime modifiedAt;

  String get fileName => p.basename(path);
}

/// 로컬 우선 백업 서비스 — manifest(DB) + 사진을 **단일 zip**으로 묶는다(8·9장).
///
/// 자체 서버에 보관하지 않으며, 만들어진 zip은 사용자가 직접 본인 클라우드/메일로
/// 공유(`share_plus`)하거나 기기 변경 시 복원에 쓴다. 구글 드라이브/iCloud 자동
/// 백업은 동일한 manifest/zip 위에 [DatabaseBackup]을 재사용해 얹는다(작업 #future).
class LocalBackupService {
  LocalBackupService(this._db);

  final AppDatabase _db;

  static const _photosPrefix = 'photos/';
  static const _thumbsPrefix = 'thumbs/';
  static const _decoratedPrefix = 'decorated/';
  static const _manifestName = 'manifest.json';
  static const _settingsFile = 'settings.json';

  /// 현재 DB+사진+꾸민사진+설정을 zip으로 만들어 documents/backups 에 저장하고 경로 반환.
  Future<String> createBackup({DateTime? now}) async {
    final stamp = now ?? DateTime.now();
    // DB 밖 설정(생일·키·앱잠금·토글)도 함께 manifest에 싣는다(누수 방지).
    final settings = await _readSettingsJson();
    final manifest =
        await DatabaseBackup(_db).exportManifest(now: stamp, settings: settings);

    final archive = Archive()
      ..addFile(ArchiveFile.string(_manifestName, jsonEncode(manifest)));

    // 사진 원본/썸네일/꾸민사진 동봉(절대경로는 DB에서 직접 조회).
    final captures = await _db.select(_db.captures).get();
    for (final c in captures) {
      _addIfExists(archive, '$_photosPrefix${p.basename(c.filePath)}', c.filePath);
      _addIfExists(archive, '$_thumbsPrefix${p.basename(c.thumbPath)}', c.thumbPath);
      final decorated = c.decoratedPath;
      if (decorated != null) {
        _addIfExists(
            archive, '$_decoratedPrefix${p.basename(decorated)}', decorated);
      }
    }

    final bytes = ZipEncoder().encode(archive);

    final backupsDir = await _ensureDir('backups');
    final fileName = 'our_day_backup_${stamp.millisecondsSinceEpoch}.zip';
    final outPath = p.join(backupsDir.path, fileName);
    await File(outPath).writeAsBytes(bytes);
    return outPath;
  }

  /// documents/backups 의 백업 파일 목록(최신순).
  Future<List<BackupFileInfo>> listBackups() async {
    final backupsDir = await _ensureDir('backups');
    final files = backupsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.zip'))
        .toList();
    final infos = files.map((f) {
      final stat = f.statSync();
      return BackupFileInfo(
        path: f.path,
        sizeBytes: stat.size,
        modifiedAt: stat.modified,
      );
    }).toList()
      ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return infos;
  }

  /// zip 백업에서 복원. 사진·꾸민사진·설정을 documents 로 풀고 DB를 교체한다.
  /// 반환값: 복원된 Capture 수.
  Future<int> restoreFromFile(String zipPath) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final capturesDir = await _ensureDir('captures');
    final thumbsDir = await _ensureDir('thumbs');
    final decoratedDir = await _ensureDir('exports'); // 꾸민사진 저장 위치

    Map<String, dynamic>? manifest;
    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      final name = entry.name;
      if (name == _manifestName) {
        manifest =
            jsonDecode(utf8.decode(entry.content)) as Map<String, dynamic>;
      } else if (name.startsWith(_photosPrefix)) {
        await _writeInto(capturesDir, p.basename(name), entry.content);
      } else if (name.startsWith(_thumbsPrefix)) {
        await _writeInto(thumbsDir, p.basename(name), entry.content);
      } else if (name.startsWith(_decoratedPrefix)) {
        await _writeInto(decoratedDir, p.basename(name), entry.content);
      }
    }

    if (manifest == null) {
      throw const FormatException('백업 파일에 manifest.json이 없습니다.');
    }

    final restored = await DatabaseBackup(_db).importManifest(
      manifest,
      capturesDir: capturesDir.path,
      thumbsDir: thumbsDir.path,
      decoratedDir: decoratedDir.path,
      replace: true,
    );

    // DB 밖 설정(생일·키·앱잠금·토글) 복원 — settings.json 덮어쓰기.
    // 호출 측은 복원 후 appSettingsProvider를 invalidate 해 다시 읽어야 한다.
    final settings = DatabaseBackup.settingsOf(manifest);
    if (settings != null) {
      await _writeSettingsJson(settings);
    }

    return restored;
  }

  /// 백업 파일 1건 삭제.
  Future<void> deleteBackup(String path) async {
    final f = File(path);
    if (f.existsSync()) await f.delete();
  }

  // ── 헬퍼 ──

  /// documents/settings.json 을 Map으로 읽음(없거나 손상 시 null).
  Future<Map<String, dynamic>?> _readSettingsJson() async {
    final docs = await getApplicationDocumentsDirectory();
    final f = File(p.join(docs.path, _settingsFile));
    if (!f.existsSync()) return null;
    try {
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// documents/settings.json 을 원자적으로 덮어쓴다(복원 시).
  Future<void> _writeSettingsJson(Map<String, dynamic> settings) async {
    final docs = await getApplicationDocumentsDirectory();
    final path = p.join(docs.path, _settingsFile);
    final tmp = File('$path.tmp');
    await tmp.writeAsString(jsonEncode(settings), flush: true);
    await tmp.rename(path);
  }

  void _addIfExists(Archive archive, String name, String sourcePath) {
    final f = File(sourcePath);
    if (f.existsSync()) {
      archive.addFile(ArchiveFile.bytes(name, f.readAsBytesSync()));
    }
  }

  Future<void> _writeInto(Directory dir, String name, List<int> bytes) async {
    await File(p.join(dir.path, name)).writeAsBytes(bytes);
  }

  Future<Directory> _ensureDir(String name) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, name));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }
}

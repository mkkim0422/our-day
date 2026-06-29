import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../core/constants/enums.dart';
import '../../data/db/app_database.dart';

/// DB ↔ 백업 manifest(JSON) 직렬화 (8·9장).
///
/// 모든 백업 타겟(로컬 zip·구글 드라이브·iCloud)이 **공통으로 재사용**하는 기반.
/// 사진 파일 경로는 기기마다 다르므로 manifest에는 **파일명(basename)만** 저장하고,
/// 복원 시 새 기기의 디렉터리 기준으로 절대경로를 다시 만든다(이식성).
class DatabaseBackup {
  DatabaseBackup(this._db);

  final AppDatabase _db;

  /// manifest 포맷 버전(향후 마이그레이션 대비).
  /// v2: 구성원(members)·태그(captureMembers)·꾸민사진(decoratedFile)·
  ///     정렬순서(sortIndex)·앱설정(settings)을 포함하도록 확장(누수 방지).
  static const int formatVersion = 2;

  /// 현재 DB 전체를 manifest(Map)로 직렬화. 사진 바이트는 포함하지 않는다
  /// (파일 동봉은 [LocalBackupService]가 담당).
  ///
  /// [settings]는 DB 밖(파일)에 있는 앱 설정(생일·키·앱잠금·토글 등)의 JSON.
  /// 백업 타겟(로컬 zip·구글·iCloud)이 동일 manifest로 전체를 실어 나르도록 함께 담는다.
  Future<Map<String, dynamic>> exportManifest({
    DateTime? now,
    Map<String, dynamic>? settings,
  }) async {
    final accounts = await _db.select(_db.accounts).get();
    final projects = await _db.select(_db.projects).get();
    final members = await _db.select(_db.members).get();
    final places = await _db.select(_db.places).get();
    final captures = await _db.select(_db.captures).get();
    final captureMembers = await _db.select(_db.captureMembers).get();

    return {
      'version': formatVersion,
      'exportedAt': (now ?? DateTime.now()).toIso8601String(),
      'account': accounts.isEmpty ? null : _accountToMap(accounts.first),
      'projects': projects.map(_projectToMap).toList(),
      'members': members.map(_memberToMap).toList(),
      'places': places.map(_placeToMap).toList(),
      'captures': captures.map(_captureToMap).toList(),
      'captureMembers': captureMembers.map(_captureMemberToMap).toList(),
      'settings': settings,
    };
  }

  /// manifest를 DB에 적용. 사진 파일 경로는 [capturesDir]/[thumbsDir] 기준으로
  /// 재구성한다. [replace]면 기존 데이터를 비우고 교체(기기 복원 시나리오).
  ///
  /// 반환값: 복원된 Capture 수.
  Future<int> importManifest(
    Map<String, dynamic> manifest, {
    required String capturesDir,
    required String thumbsDir,
    required String decoratedDir,
    bool replace = true,
  }) async {
    return _db.transaction(() async {
      if (replace) {
        // 프로젝트 삭제 시 FK cascade로 places/captures/members/태그도 정리됨.
        await _db.delete(_db.projects).go();
        await _db.delete(_db.accounts).go();
      }

      final account = manifest['account'] as Map<String, dynamic>?;
      if (account != null) {
        await _db.into(_db.accounts).insert(
              _accountCompanion(account),
              mode: InsertMode.insertOrReplace,
            );
      }

      // FK 순서: projects → members → places → captures → captureMembers.
      for (final pj in _list(manifest['projects'])) {
        await _db.into(_db.projects).insert(
              _projectCompanion(pj),
              mode: InsertMode.insertOrReplace,
            );
      }
      for (final m in _list(manifest['members'])) {
        await _db.into(_db.members).insert(
              _memberCompanion(m),
              mode: InsertMode.insertOrReplace,
            );
      }
      for (final pl in _list(manifest['places'])) {
        await _db.into(_db.places).insert(
              _placeCompanion(pl),
              mode: InsertMode.insertOrReplace,
            );
      }
      var restored = 0;
      for (final c in _list(manifest['captures'])) {
        await _db.into(_db.captures).insert(
              _captureCompanion(c, capturesDir, thumbsDir, decoratedDir),
              mode: InsertMode.insertOrReplace,
            );
        restored++;
      }
      for (final cm in _list(manifest['captureMembers'])) {
        await _db.into(_db.captureMembers).insert(
              _captureMemberCompanion(cm),
              mode: InsertMode.insertOrReplace,
            );
      }
      return restored;
    });
  }

  /// manifest에 담긴 앱 설정(JSON) — DB 밖 파일 복원용. 없으면 null.
  static Map<String, dynamic>? settingsOf(Map<String, dynamic> manifest) =>
      manifest['settings'] is Map
          ? Map<String, dynamic>.from(manifest['settings'] as Map)
          : null;

  // ── 직렬화(행 → Map) ──

  Map<String, dynamic> _accountToMap(Account a) => {
        'id': a.id,
        'provider': a.provider.name,
        'displayName': a.displayName,
        'backupTarget': a.backupTarget.name,
        'lastBackupAt': a.lastBackupAt?.toIso8601String(),
      };

  Map<String, dynamic> _projectToMap(Project p) => {
        'id': p.id,
        'title': p.title,
        'scheduleType': p.scheduleType.name,
        'scheduleConfig': p.scheduleConfig,
        'coverPhotoId': p.coverPhotoId,
        'eventPeg': p.eventPeg.name,
        'createdAt': p.createdAt.toIso8601String(),
      };

  Map<String, dynamic> _memberToMap(Member m) => {
        'id': m.id,
        'projectId': m.projectId,
        'name': m.name,
        'role': m.role,
      };

  Map<String, dynamic> _captureMemberToMap(CaptureMember cm) => {
        'captureId': cm.captureId,
        'memberId': cm.memberId,
      };

  Map<String, dynamic> _placeToMap(Place pl) => {
        'id': pl.id,
        'projectId': pl.projectId,
        'label': pl.label,
        'latitude': pl.latitude,
        'longitude': pl.longitude,
        'radiusM': pl.radiusM,
        'captureCount': pl.captureCount,
        'geofenceEnabled': pl.geofenceEnabled,
      };

  Map<String, dynamic> _captureToMap(Capture c) => {
        'id': c.id,
        'projectId': c.projectId,
        // 경로 대신 파일명만 저장(이식성).
        'photoFile': p.basename(c.filePath),
        'thumbFile': p.basename(c.thumbPath),
        'capturedAt': c.capturedAt.toIso8601String(),
        'periodLabel': c.periodLabel,
        'alignmentMeta': c.alignmentMeta,
        'note': c.note,
        'placeId': c.placeId,
        'backupState': c.backupState.name,
        // 꾸민 사진 파일명(있으면) + 사용자 정렬 순서(누수 방지).
        'decoratedFile':
            c.decoratedPath == null ? null : p.basename(c.decoratedPath!),
        'sortIndex': c.sortIndex,
      };

  // ── 역직렬화(Map → Companion) ──

  AccountsCompanion _accountCompanion(Map<String, dynamic> m) =>
      AccountsCompanion.insert(
        id: m['id'] as String,
        provider: AccountProvider.values.byName(m['provider'] as String),
        displayName: Value(m['displayName'] as String?),
        backupTarget: Value(
          BackupTarget.values.byName(m['backupTarget'] as String? ?? 'none'),
        ),
        lastBackupAt: Value(_parseDate(m['lastBackupAt'])),
      );

  MembersCompanion _memberCompanion(Map<String, dynamic> m) =>
      MembersCompanion.insert(
        id: m['id'] as String,
        projectId: m['projectId'] as String,
        name: m['name'] as String,
        role: Value(m['role'] as String?),
      );

  CaptureMembersCompanion _captureMemberCompanion(Map<String, dynamic> m) =>
      CaptureMembersCompanion.insert(
        captureId: m['captureId'] as String,
        memberId: m['memberId'] as String,
      );

  ProjectsCompanion _projectCompanion(Map<String, dynamic> m) =>
      ProjectsCompanion.insert(
        id: m['id'] as String,
        title: m['title'] as String,
        scheduleType: ScheduleType.values.byName(m['scheduleType'] as String),
        scheduleConfig: Value(_asStringMap(m['scheduleConfig'])),
        coverPhotoId: Value(m['coverPhotoId'] as String?),
        eventPeg: Value(
          EventPeg.values.byName(m['eventPeg'] as String? ?? 'none'),
        ),
        createdAt: Value(_parseDate(m['createdAt']) ?? DateTime.now()),
      );

  PlacesCompanion _placeCompanion(Map<String, dynamic> m) =>
      PlacesCompanion.insert(
        id: m['id'] as String,
        projectId: m['projectId'] as String,
        label: m['label'] as String,
        latitude: (m['latitude'] as num).toDouble(),
        longitude: (m['longitude'] as num).toDouble(),
        radiusM: Value(m['radiusM'] as int? ?? 200),
        captureCount: Value(m['captureCount'] as int? ?? 0),
        geofenceEnabled: Value(m['geofenceEnabled'] as bool? ?? false),
      );

  CapturesCompanion _captureCompanion(
    Map<String, dynamic> m,
    String capturesDir,
    String thumbsDir,
    String decoratedDir,
  ) {
    final decoratedFile = m['decoratedFile'] as String?;
    return CapturesCompanion.insert(
      id: m['id'] as String,
      projectId: m['projectId'] as String,
      filePath: p.join(capturesDir, m['photoFile'] as String),
      thumbPath: p.join(thumbsDir, m['thumbFile'] as String),
      capturedAt: _parseDate(m['capturedAt']) ?? DateTime.now(),
      periodLabel: m['periodLabel'] as String,
      alignmentMeta: Value(_asStringMapOrNull(m['alignmentMeta'])),
      note: Value(m['note'] as String?),
      placeId: Value(m['placeId'] as String?),
      backupState: Value(
        BackupState.values.byName(m['backupState'] as String? ?? 'localOnly'),
      ),
      decoratedPath: Value(
        decoratedFile == null ? null : p.join(decoratedDir, decoratedFile),
      ),
      sortIndex: Value(m['sortIndex'] as int?),
    );
  }

  // ── 헬퍼 ──

  static List<Map<String, dynamic>> _list(Object? raw) =>
      (raw as List?)?.cast<Map<String, dynamic>>() ?? const [];

  static Map<String, dynamic> _asStringMap(Object? raw) =>
      raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

  static Map<String, dynamic>? _asStringMapOrNull(Object? raw) =>
      raw is Map ? Map<String, dynamic>.from(raw) : null;

  static DateTime? _parseDate(Object? raw) =>
      raw is String ? DateTime.tryParse(raw) : null;
}

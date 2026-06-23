import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/enums.dart';
import '../../core/utils/schedule_period.dart';
import '../db/app_database.dart';

/// 촬영(Capture) 접근. 4가지 입력 경로(②-1) 모두 이 계층을 통해 1건으로 저장.
class CaptureRepository {
  CaptureRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// 프로젝트의 촬영들을 시계열(최신순)로 구독.
  Stream<List<Capture>> watchByProject(String projectId) {
    final q = _db.select(_db.captures)
      ..where((c) => c.projectId.equals(projectId))
      ..orderBy([(c) => OrderingTerm.desc(c.capturedAt)]);
    return q.watch();
  }

  /// 가장 최근 촬영(오버레이 기본값·킬러 기능 4장).
  Future<Capture?> latestForProject(String projectId) {
    final q = _db.select(_db.captures)
      ..where((c) => c.projectId.equals(projectId))
      ..orderBy([(c) => OrderingTerm.desc(c.capturedAt)])
      ..limit(1);
    return q.getSingleOrNull();
  }

  Future<int> countByProject(String projectId) async {
    final count = _db.captures.id.count();
    final q = _db.selectOnly(_db.captures)
      ..addColumns([count])
      ..where(_db.captures.projectId.equals(projectId));
    final row = await q.getSingle();
    return row.read(count) ?? 0;
  }

  /// 촬영 저장. project의 주기로 period_label을 계산해 채운다.
  Future<Capture> create({
    required Project project,
    required String filePath,
    required String thumbPath,
    required DateTime capturedAt,
    Map<String, dynamic>? alignmentMeta,
    String? note,
    String? placeId,
  }) async {
    final id = _uuid.v4();
    final label = SchedulePeriod.periodLabel(
      project.scheduleType,
      project.scheduleConfig,
      capturedAt,
    );
    await _db.into(_db.captures).insert(
          CapturesCompanion.insert(
            id: id,
            projectId: project.id,
            filePath: filePath,
            thumbPath: thumbPath,
            capturedAt: capturedAt,
            periodLabel: label,
            alignmentMeta: Value(alignmentMeta),
            note: Value(note),
            placeId: Value(placeId),
          ),
        );
    return (_db.select(_db.captures)..where((c) => c.id.equals(id)))
        .getSingle();
  }

  Future<void> updateAlignment(String id, Map<String, dynamic> meta) {
    return (_db.update(_db.captures)..where((c) => c.id.equals(id)))
        .write(CapturesCompanion(alignmentMeta: Value(meta)));
  }

  Future<void> setBackupState(String id, BackupState state) {
    return (_db.update(_db.captures)..where((c) => c.id.equals(id)))
        .write(CapturesCompanion(backupState: Value(state)));
  }

  Future<void> delete(String id) {
    return (_db.delete(_db.captures)..where((c) => c.id.equals(id))).go();
  }

  /// 이번 기간에 이미 촬영했는지(홈 CTA·진척 게이지 6장).
  Future<bool> hasCaptureInCurrentPeriod(Project project, DateTime now) async {
    final targetKey = SchedulePeriod.periodKey(
      project.scheduleType,
      project.scheduleConfig,
      now,
    );
    final caps = await (_db.select(_db.captures)
          ..where((c) => c.projectId.equals(project.id)))
        .get();
    return caps.any((c) =>
        SchedulePeriod.periodKey(
          project.scheduleType,
          project.scheduleConfig,
          c.capturedAt,
        ) ==
        targetKey);
  }
}

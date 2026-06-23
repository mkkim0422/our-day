import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/enums.dart';
import '../db/app_database.dart';

/// 프로젝트(촬영 주제) 접근.
class ProjectRepository {
  ProjectRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Stream<List<Project>> watchAll() {
    final q = _db.select(_db.projects)
      ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]);
    return q.watch();
  }

  Future<Project?> getById(String id) {
    return (_db.select(_db.projects)..where((p) => p.id.equals(id)))
        .getSingleOrNull();
  }

  /// 새 프로젝트 생성. id(uuid) 자동 발급.
  Future<Project> create({
    required String title,
    required ScheduleType scheduleType,
    Map<String, dynamic> scheduleConfig = const {},
    EventPeg eventPeg = EventPeg.none,
  }) async {
    final id = _uuid.v4();
    await _db.into(_db.projects).insert(
          ProjectsCompanion.insert(
            id: id,
            title: title,
            scheduleType: scheduleType,
            scheduleConfig: Value(scheduleConfig),
            eventPeg: Value(eventPeg),
          ),
        );
    return (await getById(id))!;
  }

  Future<void> setCoverPhoto(String projectId, String captureId) {
    return (_db.update(_db.projects)..where((p) => p.id.equals(projectId)))
        .write(ProjectsCompanion(coverPhotoId: Value(captureId)));
  }

  Future<void> updateSchedule(
    String projectId, {
    required ScheduleType scheduleType,
    required Map<String, dynamic> scheduleConfig,
  }) {
    return (_db.update(_db.projects)..where((p) => p.id.equals(projectId)))
        .write(ProjectsCompanion(
      scheduleType: Value(scheduleType),
      scheduleConfig: Value(scheduleConfig),
    ));
  }

  /// 프로젝트 삭제(FK cascade로 하위 Capture/Place/Member도 제거).
  Future<void> delete(String id) {
    return (_db.delete(_db.projects)..where((p) => p.id.equals(id))).go();
  }
}

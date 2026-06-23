import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';

/// 구성원(Member) + 촬영 태깅 접근 (아이디어7 — 누가 사진에 있는지).
class MemberRepository {
  MemberRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Stream<List<Member>> watchByProject(String projectId) {
    final q = _db.select(_db.members)
      ..where((m) => m.projectId.equals(projectId))
      ..orderBy([(m) => OrderingTerm.asc(m.name)]);
    return q.watch();
  }

  Future<List<Member>> listByProject(String projectId) {
    final q = _db.select(_db.members)
      ..where((m) => m.projectId.equals(projectId))
      ..orderBy([(m) => OrderingTerm.asc(m.name)]);
    return q.get();
  }

  Future<Member> create({
    required String projectId,
    required String name,
    String? role,
  }) async {
    final id = _uuid.v4();
    await _db.into(_db.members).insert(
          MembersCompanion.insert(
            id: id,
            projectId: projectId,
            name: name,
            role: Value(role),
          ),
        );
    return (_db.select(_db.members)..where((m) => m.id.equals(id)))
        .getSingle();
  }

  Future<void> delete(String id) =>
      (_db.delete(_db.members)..where((m) => m.id.equals(id))).go();

  // ── 태깅(촬영 ↔ 구성원) ──

  /// 한 촬영에 태그된 구성원 id들.
  Future<List<String>> memberIdsForCapture(String captureId) async {
    final rows = await (_db.select(_db.captureMembers)
          ..where((cm) => cm.captureId.equals(captureId)))
        .get();
    return rows.map((r) => r.memberId).toList();
  }

  /// 한 촬영의 태그를 [memberIds]로 교체.
  Future<void> setMembersForCapture(
      String captureId, List<String> memberIds) async {
    await _db.transaction(() async {
      await (_db.delete(_db.captureMembers)
            ..where((cm) => cm.captureId.equals(captureId)))
          .go();
      for (final memberId in memberIds) {
        await _db.into(_db.captureMembers).insert(
              CaptureMembersCompanion.insert(
                  captureId: captureId, memberId: memberId),
            );
      }
    });
  }

  /// 특정 구성원이 태그된 촬영 id 집합(타임랩스·앨범 필터용).
  Future<Set<String>> captureIdsForMember(String memberId) async {
    final rows = await (_db.select(_db.captureMembers)
          ..where((cm) => cm.memberId.equals(memberId)))
        .get();
    return rows.map((r) => r.captureId).toSet();
  }
}

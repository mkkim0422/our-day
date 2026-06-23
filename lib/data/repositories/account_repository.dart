import 'package:drift/drift.dart';

import '../../core/constants/enums.dart';
import '../db/app_database.dart';

/// 계정 접근. MVP는 단일 사용자 → 보통 0~1개 행만 존재.
class AccountRepository {
  AccountRepository(this._db);

  final AppDatabase _db;

  /// 현재 로그인된 계정(없으면 null).
  Future<Account?> current() => _db.select(_db.accounts).getSingleOrNull();

  Stream<Account?> watchCurrent() =>
      _db.select(_db.accounts).watchSingleOrNull();

  /// 로그인 시 계정 생성/갱신(provider uid 기반 PK).
  Future<void> upsert({
    required String id,
    required AccountProvider provider,
    String? displayName,
  }) {
    return _db.into(_db.accounts).insertOnConflictUpdate(
          AccountsCompanion.insert(
            id: id,
            provider: provider,
            displayName: Value(displayName),
          ),
        );
  }

  Future<void> setBackupTarget(String id, BackupTarget target) {
    return (_db.update(_db.accounts)..where((a) => a.id.equals(id)))
        .write(AccountsCompanion(backupTarget: Value(target)));
  }

  Future<void> setLastBackupAt(String id, DateTime at) {
    return (_db.update(_db.accounts)..where((a) => a.id.equals(id)))
        .write(AccountsCompanion(lastBackupAt: Value(at)));
  }

  /// 로그아웃 — 계정 행 제거(사진·DB 본문은 유지).
  Future<void> clear() => _db.delete(_db.accounts).go();
}

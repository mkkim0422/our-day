import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/enums.dart';
import 'converters.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// 로컬 우선(local-first) DB (1·9장).
///
/// 사진 원본/썸네일은 파일시스템, DB에는 경로·메타데이터만 보관.
@DriftDatabase(
    tables: [Accounts, Projects, Members, CaptureMembers, Captures, Places])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// 테스트용: 인메모리 또는 주입된 executor 사용.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v2: 구성원 태깅 N:N 테이블 추가(아이디어7).
          if (from < 2) await m.createTable(captureMembers);
          // v3: 꾸미기 결과 경로(원본 보존, 기록에 꾸민 버전 표시).
          if (from < 3) await m.addColumn(captures, captures.decoratedPath);
        },
        beforeOpen: (details) async {
          // FK 제약(onDelete cascade/setNull) 활성화.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

/// 백그라운드 isolate에서 sqlite를 여는 연결(메인 스레드 차단 방지).
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'our_day.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

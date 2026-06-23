import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import 'account_repository.dart';
import 'capture_repository.dart';
import 'member_repository.dart';
import 'place_repository.dart';
import 'project_repository.dart';

/// DB·repository 의존성 주입 지점(riverpod).
///
/// 화면(features)은 이 provider들을 통해서만 데이터에 접근한다(계층 분리, 1장).

/// 앱 단일 DB 인스턴스.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(ref.watch(databaseProvider)),
);

final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => ProjectRepository(ref.watch(databaseProvider)),
);

final captureRepositoryProvider = Provider<CaptureRepository>(
  (ref) => CaptureRepository(ref.watch(databaseProvider)),
);

final placeRepositoryProvider = Provider<PlaceRepository>(
  (ref) => PlaceRepository(ref.watch(databaseProvider)),
);

final memberRepositoryProvider = Provider<MemberRepository>(
  (ref) => MemberRepository(ref.watch(databaseProvider)),
);

/// 프로젝트 구성원 목록(스트림). 태깅·필터·관리 UI에서 구독.
final membersProvider = StreamProvider.family<List<Member>, String>(
  (ref, projectId) =>
      ref.watch(memberRepositoryProvider).watchByProject(projectId),
);

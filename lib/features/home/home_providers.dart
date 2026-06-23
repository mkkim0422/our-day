import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/repositories/providers.dart';

/// 홈/타임라인(② 화면) 상태 프로바이더.
///
/// 화면은 repository를 직접 만지지 않고 이 provider들을 구독한다(계층 분리, 1장).

/// 모든 프로젝트(최신순). 온보딩 분기·프로젝트 전환에 사용.
final projectsProvider = StreamProvider<List<Project>>(
  (ref) => ref.watch(projectRepositoryProvider).watchAll(),
);

/// 특정 프로젝트의 촬영들(시계열 최신순). 타임라인 그리드·진척 게이지의 원천.
final capturesProvider = StreamProvider.family<List<Capture>, String>(
  (ref, projectId) =>
      ref.watch(captureRepositoryProvider).watchByProject(projectId),
);

/// 현재 홈에 표시할 프로젝트 id(여러 프로젝트 전환용). null이면 가장 최근 것.
class SelectedProjectId extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final selectedProjectIdProvider =
    NotifierProvider<SelectedProjectId, String?>(SelectedProjectId.new);

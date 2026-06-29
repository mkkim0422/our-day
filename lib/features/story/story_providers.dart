import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/repositories/providers.dart';
import '../../services/providers.dart';
import '../home/home_providers.dart';
import 'growth_story.dart';

/// 프로젝트의 성장 스토리(아이·가족 중심) 자동 생성. 우리 앱 데이터만 사용.
final growthStoriesProvider =
    FutureProvider.family<List<GrowthStory>, String>((ref, projectId) async {
  final caps = await ref.watch(capturesProvider(projectId).future);
  final ascAll = [...caps]
    ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));

  final places = await ref.watch(placesProvider(projectId).future);
  final placeLabels = {for (final p in places) p.id: p.label};

  final memberRepo = ref.watch(memberRepositoryProvider);
  final members = await ref.watch(membersProvider(projectId).future);
  final byId = {for (final c in ascAll) c.id: c};
  final memberGroups = <({String name, List<Capture> captures})>[];
  for (final m in members) {
    final ids = await memberRepo.captureIdsForMember(m.id);
    final list = ids.map((id) => byId[id]).whereType<Capture>().toList()
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
    if (list.isNotEmpty) memberGroups.add((name: m.name, captures: list));
  }

  final settings = await ref.watch(appSettingsProvider.future);
  final birthday = settings.projectBirthdays[projectId];

  return GrowthStoryBuilder.build(
    capturesAsc: ascAll,
    placeLabels: placeLabels,
    memberGroups: memberGroups,
    birthday: birthday,
  );
});

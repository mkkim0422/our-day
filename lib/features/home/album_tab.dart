import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../capture/capture_detail_screen.dart';
import 'home_providers.dart';
import 'widgets/timeline_grid.dart';
import '../../data/db/app_database.dart';

/// 앨범 탭 — 프로젝트의 모든 기록을 한눈에(시간 역순 그리드). 셀 탭 → 상세.
class AlbumTab extends ConsumerWidget {
  const AlbumTab({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capturesAsync = ref.watch(capturesProvider(project.id));
    return capturesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('불러오기 오류: $e')),
      data: (captures) {
        if (captures.isEmpty) return _empty(context);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            TimelineGrid(
              captures: captures,
              onTapCell: (c) => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      CaptureDetailScreen(project: project, capture: c),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _empty(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined,
                size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('앨범이 비어 있어요',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('한 컷을 남기면 여기에 모입니다.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

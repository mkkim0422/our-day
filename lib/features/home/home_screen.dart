import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ads/ad_slot.dart';
import '../../core/theme/app_theme.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/providers.dart';
import '../../services/providers.dart';
import '../capture/backfill_screen.dart';
import '../capture/capture_detail_screen.dart';
import '../capture/capture_screen.dart';
import '../compare/compare_screen.dart';
import 'home_providers.dart';
import 'widgets/milestone_card.dart';
import 'widgets/progress_gauge.dart';
import 'widgets/timeline_grid.dart';

/// ② 홈 탭 — "이번 기간 한 컷" CTA + 진척 게이지 + 최근 기록(MainShell의 첫 탭).
class HomeTab extends ConsumerWidget {
  const HomeTab({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capturesAsync = ref.watch(capturesProvider(project.id));
    return capturesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('불러오기 오류: $e')),
      data: (captures) => _content(context, ref, captures),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, List<Capture> captures) {
    final now = DateTime.now();
    final done = hasCaptureInCurrentPeriod(project, captures, now);
    final latest = captures.isNotEmpty ? captures.first : null;

    // 마일스톤(백일·돌 등) — 생일이 설정돼 있고 그 시점 근처 사진이 있으면 노출.
    final birthday =
        ref.watch(appSettingsProvider).value?.projectBirthdays[project.id];
    final milestone = (birthday != null && captures.length >= 2)
        ? MilestoneCard.pick(birthday, captures, now)
        : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _CtaCard(done: done, onTap: () => _openCapture(context, ref, latest)),
        // 축하 노출: 백일·돌 등 마일스톤에 도달했으면 가장 위에 띄운다.
        if (milestone != null) ...[
          const SizedBox(height: 12),
          MilestoneCard(
            milestone: milestone.milestone,
            capture: milestone.capture,
            onTap: () => _openCompare(context),
          ),
        ],
        // 보상 노출: 2컷 이상이면 "변화를 영상으로" 보러 가는 입구를 위로 올린다.
        if (captures.length >= 2) ...[
          const SizedBox(height: 12),
          _SeeChangesCard(
            count: captures.length,
            onTap: () => _openCompare(context),
          ),
        ],
        const SizedBox(height: 16),
        ProgressGauge(project: project, captures: captures, now: now),
        const SizedBox(height: 24),
        if (captures.isEmpty)
          _EmptyTimeline(onBackfill: () => _openBackfill(context))
        else ...[
          Row(
            children: [
              Text('모든 기록', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 8),
              Text('${captures.length}컷',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _openBackfill(context),
                icon: const Icon(Icons.library_add_outlined, size: 18),
                label: const Text('예전 사진 채우기'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 전체 기록 그리드(앨범 탭 = 촬영 CTA + 진척 + 모든 사진).
          // 사진을 길게 누르면 드래그로 순서를 바꿀 수 있다(모든 곳에 반영).
          TimelineGrid(
            captures: captures,
            onTapCell: (c) => _openDetail(context, c),
            onReorder: (ordered) => ref
                .read(captureRepositoryProvider)
                .reorder(ordered.map((c) => c.id).toList()),
          ),
        ],
        const SizedBox(height: 16),
        const AdSlot(placement: AdPlacement.homeBanner),
      ],
    );
  }

  Future<void> _openCapture(
      BuildContext context, WidgetRef ref, Capture? reference) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CaptureScreen(project: project, referenceCapture: reference),
      ),
    );
  }

  Future<void> _openDetail(BuildContext context, Capture capture) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CaptureDetailScreen(project: project, capture: capture),
      ),
    );
  }

  Future<void> _openBackfill(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BackfillScreen(project: project)),
    );
  }

  Future<void> _openCompare(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CompareScreen(project: project)),
    );
  }
}

/// "이번 기간 한 컷" CTA 카드 — 안 찍었으면 브랜드 그라데이션으로 강조,
/// 찍었으면 부드러운 완료 카드(② 화면).
class _CtaCard extends StatelessWidget {
  const _CtaCard({required this.done, required this.onTap});
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(22);

    // 그라데이션이 파스텔이라 양쪽 상태 모두 진한 플럼 텍스트로 가독성 확보.
    final fg = scheme.onSurface;
    final subFg = scheme.onSurfaceVariant;

    final decoration = done
        ? BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.45),
            borderRadius: radius,
          )
        : BoxDecoration(
            borderRadius: radius,
            gradient: const LinearGradient(
              colors: AppTheme.brandGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.brandGradient.last.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          );

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                  child: Icon(
                    done ? Icons.check_rounded : Icons.camera_alt_rounded,
                    size: 28,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        done ? '한 컷 더 찍기' : '이번 기간 한 컷 찍기',
                        style: text.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800, color: fg),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        done
                            ? '이번 기간은 이미 기록했어요 ✓'
                            : '같은 포즈로 그날의 우리를 남겨요',
                        style: text.bodySmall?.copyWith(color: subFg),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: fg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "변화 보기" 카드 — 2컷 이상일 때 홈 상단에 보상(타임랩스·비교)을 노출한다.
class _SeeChangesCard extends StatelessWidget {
  const _SeeChangesCard({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(18);
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Icon(Icons.play_circle_fill_rounded,
                  size: 34, color: scheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('변화 보기',
                        style: text.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('$count컷을 타임랩스·비교로 한눈에',
                        style: text.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// 빈 타임라인 안내 — 촬영은 위의 CTA 카드가 단일 기본 액션이므로 여기선
/// 설명 + '예전 사진 채우기'(별개 동작)만 둔다(버튼 중복 제거).
class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline({required this.onBackfill});
  final VoidCallback onBackfill;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.photo_camera_back_outlined,
              size: 44, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('아직 사진이 없어요', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            '위에서 첫 컷을 찍으면 여기에 그날의 우리가 쌓입니다.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onBackfill,
            icon: const Icon(Icons.library_add_outlined),
            label: const Text('예전 사진으로 한번에 채우기'),
          ),
        ],
      ),
    );
  }
}

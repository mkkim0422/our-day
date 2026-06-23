import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ads/ad_slot.dart';
import '../../data/db/app_database.dart';
import '../capture/backfill_screen.dart';
import '../capture/capture_detail_screen.dart';
import '../capture/capture_screen.dart';
import '../compare/compare_screen.dart';
import 'home_providers.dart';
import 'widgets/progress_gauge.dart';

/// ② 홈 / 타임라인 — 앱의 중심 화면.
///
/// "이번 기간 한 컷" CTA + 과거 기록 그리드 + 진척 게이지(6장). 하단에 허용된
/// 배너 광고 슬롯(6-1장). CTA/그리드 탭으로 촬영·상세로 이동.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capturesAsync = ref.watch(capturesProvider(project.id));
    final canCompare = (capturesAsync.value?.length ?? 0) >= 2;

    return Scaffold(
      appBar: AppBar(
        title: Text(project.title),
        actions: [
          if (canCompare)
            IconButton(
              icon: const Icon(Icons.auto_awesome_motion_outlined),
              tooltip: '비교 · 타임랩스',
              onPressed: () => _openCompare(context),
            ),
          IconButton(
            icon: const Icon(Icons.library_add_outlined),
            tooltip: '예전 사진 채우기',
            onPressed: () => _openBackfill(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '설정',
            onPressed: () => _comingSoon(context, '설정 / 백업'),
          ),
        ],
      ),
      body: capturesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오기 오류: $e')),
        data: (captures) => _content(context, ref, captures),
      ),
      bottomNavigationBar: const SafeArea(
        child: AdSlot(placement: AdPlacement.homeBanner),
      ),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, List<Capture> captures) {
    final now = DateTime.now();
    final done = hasCaptureInCurrentPeriod(project, captures, now);
    final latest = captures.isNotEmpty ? captures.first : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _CtaCard(
          done: done,
          onTap: () => _openCapture(context, ref, latest),
        ),
        const SizedBox(height: 16),
        ProgressGauge(project: project, captures: captures, now: now),
        const SizedBox(height: 24),
        Text('지난 기록', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (captures.isEmpty)
          _EmptyTimeline(
            onTap: () => _openCapture(context, ref, null),
            onBackfill: () => _openBackfill(context),
          )
        else
          _TimelineGrid(
            captures: captures,
            onTapCell: (capture) => _openDetail(context, capture),
          ),
      ],
    );
  }

  Future<void> _openCompare(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CompareScreen(project: project)),
    );
  }

  /// 썸네일 탭 → 풀사이즈 사진 상세(명세 ②).
  Future<void> _openDetail(BuildContext context, Capture capture) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CaptureDetailScreen(project: project, capture: capture),
      ),
    );
  }

  /// 과거 일괄 채우기(②-1 입력경로 3) 진입.
  Future<void> _openBackfill(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BackfillScreen(project: project)),
    );
  }

  Future<void> _openCapture(
    BuildContext context,
    WidgetRef ref,
    Capture? reference,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CaptureScreen(
          project: project,
          referenceCapture: reference,
        ),
      ),
    );
    // 저장은 스트림(capturesProvider)으로 자동 반영되므로 별도 갱신 불필요.
  }

  void _comingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label — 곧 제공됩니다.')),
    );
  }
}

/// "이번 기간 한 컷" CTA 카드 — 안 찍었으면 강조, 찍었으면 완료 표시(② 화면).
class _CtaCard extends StatelessWidget {
  const _CtaCard({required this.done, required this.onTap});
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Material(
      color: done ? scheme.surfaceContainerHighest : scheme.primaryContainer,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(
                done ? Icons.check_circle : Icons.camera_alt_rounded,
                size: 40,
                color: done ? scheme.primary : scheme.onPrimaryContainer,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      done ? '이번 기간 촬영 완료' : '이번 기간 한 컷 찍기',
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: done ? scheme.onSurface : scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      done ? '다시 찍어 더 좋은 컷으로 바꿀 수 있어요' : '같은 포즈로 그날의 우리를 남겨요',
                      style: text.bodySmall?.copyWith(
                        color: done
                            ? scheme.onSurfaceVariant
                            : scheme.onPrimaryContainer.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: done ? scheme.onSurfaceVariant : scheme.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

/// 과거 기록 그리드(썸네일 + 기간 라벨).
class _TimelineGrid extends StatelessWidget {
  const _TimelineGrid({required this.captures, required this.onTapCell});
  final List<Capture> captures;
  final ValueChanged<Capture> onTapCell;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: captures.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, i) => _TimelineCell(
        capture: captures[i],
        onTap: () => onTapCell(captures[i]),
      ),
    );
  }
}

class _TimelineCell extends StatelessWidget {
  const _TimelineCell({required this.capture, required this.onTap});
  final Capture capture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final thumb = File(capture.thumbPath);
    // 썸네일 탭 → 비교/타임랩스(명세 ②: 상세/비교 진입).
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: thumb.existsSync()
                  ? Image.file(thumb, fit: BoxFit.cover)
                  : Container(
                      color: scheme.surfaceContainerHighest,
                      child: Icon(Icons.image_not_supported_outlined,
                          color: scheme.onSurfaceVariant),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            capture.periodLabel,
            style: Theme.of(context).textTheme.labelSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline({required this.onTap, required this.onBackfill});
  final VoidCallback onTap;
  final VoidCallback onBackfill;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.photo_camera_back_outlined,
              size: 48, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('아직 사진이 없어요', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            '첫 사진을 찍으면 여기에 그날의 우리가 쌓입니다.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.camera_alt),
            label: const Text('첫 사진 찍기'),
          ),
          const SizedBox(height: 8),
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

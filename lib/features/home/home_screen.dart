import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ads/ad_slot.dart';
import '../../core/constants/enums.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/providers.dart';
import '../../services/providers.dart';
import '../capture/backfill_screen.dart';
import '../capture/capture_detail_screen.dart';
import '../capture/capture_screen.dart';
import 'home_providers.dart';
import 'widgets/milestone_card.dart';
import 'widgets/progress_gauge.dart';
import 'widgets/timeline_grid.dart';

/// ② 앨범 탭 — 사진첩이 주인공. 흐름: 상태 한 줄(어디까지 왔나+이번 기간 넛지)
/// → 사진 그리드(+끝에 '한 컷 더') → 성장 현황(보조). 촬영은 FAB, 예전 사진·
/// 설정은 ⋮ 메뉴, 비교/타임랩스는 '다시보기' 탭이 담당(중복 입구 없음).
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

    // ── 시작하러 온 사람: 길 하나(첫 컷)만 또렷하게.
    if (captures.isEmpty) {
      return _EmptyAlbum(
        onCapture: () => _openCapture(context, ref, null),
        onBackfill: () => _openBackfill(context),
      );
    }

    // ── 모아보러 온 사람: 사진첩이 주인공. 흐름은
    //    ① 어디까지 왔나 + 이번 기간 넛지(한 줄) → ② 사진(+끝에 '한 컷 더')
    //    → ③ 성장 현황(보조). 촬영은 FAB, 예전 사진·설정은 ⋮ 메뉴가 담당.
    //    (비교/타임랩스는 상단 '다시보기' 탭이 입구 — 중복 입구를 두지 않는다.)
    final done = hasCaptureInCurrentPeriod(project, captures, now);
    final latest = captures.first;
    final birthday =
        ref.watch(appSettingsProvider).value?.projectBirthdays[project.id];
    final milestone = (birthday != null && captures.length >= 2)
        ? MilestoneCard.pick(birthday, captures, now)
        : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        _StatusNudge(
          project: project,
          count: captures.length,
          done: done,
          onCapture: () => _openCapture(context, ref, latest),
        ),
        // 축하: 백일·돌 등 마일스톤이면 위에 띄운다(탭하면 그 사진으로).
        if (milestone != null) ...[
          const SizedBox(height: 12),
          MilestoneCard(
            milestone: milestone.milestone,
            capture: milestone.capture,
            onTap: () => _openDetail(context, milestone.capture),
          ),
        ],
        const SizedBox(height: 18),
        // 사진(주인공) — 길게 누르면 순서 바꾸기, 끝 타일로 '한 컷 더'.
        TimelineGrid(
          captures: captures,
          onTapCell: (c) => _openDetail(context, c),
          onAddTap: () => _openCapture(context, ref, latest),
          onReorder: (ordered) => ref
              .read(captureRepositoryProvider)
              .reorder(ordered.map((c) => c.id).toList()),
        ),
        const SizedBox(height: 24),
        // 보조 정보: 누적·연속·기간 점(사진을 본 뒤 가볍게).
        ProgressGauge(project: project, captures: captures, now: now),
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
}

/// 상태 한 줄 — "어디까지 왔나(N번째)"와 "이번 기간 넛지"를 한 카드에 모은다.
/// 안 찍은 기간이면 [한 컷] 버튼으로 바로 촬영, 찍었으면 조용히 완료 표시.
/// (큰 CTA 카드를 따로 두지 않고 이 한 줄이 상태+다음 행동을 겸한다.)
class _StatusNudge extends StatelessWidget {
  const _StatusNudge({
    required this.project,
    required this.count,
    required this.done,
    required this.onCapture,
  });

  final Project project;
  final int count;
  final bool done;
  final VoidCallback onCapture;

  /// "이번 ○○" 자연스러운 기간 표현(주기별).
  String get _periodWord => switch (project.scheduleType) {
        ScheduleType.daily => '오늘',
        ScheduleType.weekly => '이번 주',
        ScheduleType.monthly => '이번 달',
        ScheduleType.yearly => '올해',
        ScheduleType.biweekly ||
        ScheduleType.fixedDates ||
        ScheduleType.manual =>
          '이번 차례',
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final period = _periodWord;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      decoration: BoxDecoration(
        color: done
            ? scheme.surfaceContainerHighest
            : scheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$count번째 기록',
                    style: text.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  done ? '$period 기록을 남겼어요 ✓' : '$period, 아직 안 남겼어요',
                  style: text.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (done)
            Icon(Icons.check_circle_rounded, color: scheme.primary, size: 28)
          else
            FilledButton.icon(
              onPressed: onCapture,
              icon: const Icon(Icons.camera_alt_rounded, size: 18),
              label: const Text('한 컷'),
              style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact),
            ),
        ],
      ),
    );
  }
}

/// 빈 앨범 — 시작하러 온 사람에게 길 하나(첫 컷)만 또렷하게.
class _EmptyAlbum extends StatelessWidget {
  const _EmptyAlbum({required this.onCapture, required this.onBackfill});
  final VoidCallback onCapture;
  final VoidCallback onBackfill;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_camera_outlined,
                  size: 64, color: scheme.primary),
              const SizedBox(height: 20),
              Text('첫 컷을 남겨볼까요?',
                  textAlign: TextAlign.center,
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                '같은 포즈로 그날의 우리를 기록해요.\n매 기간 한 컷이면 충분해요.',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onCapture,
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('첫 컷 찍기'),
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onBackfill,
                icon: const Icon(Icons.library_add_outlined),
                label: const Text('예전 사진 불러오기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ads/ad_slot.dart';
import '../../core/theme/app_theme.dart';
import '../../data/db/app_database.dart';
import '../capture/backfill_screen.dart';
import '../capture/capture_detail_screen.dart';
import '../capture/capture_screen.dart';
import '../compare/compare_screen.dart';
import '../onboarding/new_project_screen.dart';
import '../settings/settings_screen.dart';
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
        // 제목 탭 → 프로젝트 전환/새 프로젝트 만들기.
        title: InkWell(
          onTap: () => _openProjectSwitcher(context),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(project.title, overflow: TextOverflow.ellipsis),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
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
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
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

  /// 프로젝트 전환 시트 — 다른 프로젝트로 바꾸거나 새로 만든다.
  Future<void> _openProjectSwitcher(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _ProjectSwitcherSheet(currentId: project.id),
    );
  }

  /// 새 프로젝트 만들기 → 생성되면 그 프로젝트로 전환.
  static Future<void> createProject(BuildContext context, WidgetRef ref) async {
    final created = await Navigator.of(context).push<Project>(
      MaterialPageRoute(builder: (_) => const NewProjectScreen()),
    );
    if (created != null) {
      ref.read(selectedProjectIdProvider.notifier).select(created.id);
    }
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

    // 색/배경: 미촬영=생기 있는 그라데이션, 완료=따뜻한 연한 톤.
    final fg = done ? scheme.onSurface : Colors.white;
    final subFg = done
        ? scheme.onSurfaceVariant
        : Colors.white.withValues(alpha: 0.92);

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
                    color: done
                        ? scheme.primary.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.22),
                  ),
                  child: Icon(
                    done ? Icons.check_rounded : Icons.camera_alt_rounded,
                    size: 28,
                    color: done ? scheme.primary : Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        done ? '이번 기간 촬영 완료' : '이번 기간 한 컷 찍기',
                        style: text.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800, color: fg),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        done
                            ? '다시 찍어 더 좋은 컷으로 바꿀 수 있어요'
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

/// 프로젝트 전환/추가 바텀시트.
class _ProjectSwitcherSheet extends ConsumerWidget {
  const _ProjectSwitcherSheet({required this.currentId});
  final String currentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider).value ?? const [];
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('기록 프로젝트',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          for (final p in projects)
            ListTile(
              leading: Icon(
                p.id == currentId
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(p.title),
              onTap: () {
                ref.read(selectedProjectIdProvider.notifier).select(p.id);
                Navigator.of(context).pop();
              },
            ),
          const Divider(height: 8),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('새 프로젝트 만들기'),
            onTap: () async {
              Navigator.of(context).pop();
              await HomeScreen.createProject(context, ref);
            },
          ),
        ],
      ),
    );
  }
}

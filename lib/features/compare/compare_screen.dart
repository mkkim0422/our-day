import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../services/providers.dart';
import '../../services/timelapse/timelapse_service.dart';
import '../capture/alignment_meta.dart';
import '../home/home_providers.dart';
import 'widgets/timelapse_player.dart';

/// ⑤ 비교 / 타임랩스 — "가치 실현 순간"(변화 체감).
///
/// 구성: ① 그때 vs 지금 비교 뷰(기간 라벨) → 비교 이미지로 내보내기,
/// ② 인앱 타임랩스 재생, ③ 타임랩스 GIF 생성·공유(⑥ 바이럴 루프).
///
/// 광고 규칙(6-1장): 이 화면은 **감정의 정점(비교 뷰)** 이므로 광고를 넣지 않는다.
/// 전면 광고는 오직 타임랩스 "생성 완료" 직후의 자연스러운 휴지점에서만 허용
/// (실제 AdMob 연동은 작업 #9 — 아래 생성 완료 지점에 훅만 표시).
class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({super.key, required this.project});

  final Project project;

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  final _compareKey = GlobalKey();
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final capturesAsync = ref.watch(capturesProvider(widget.project.id));

    return Scaffold(
      appBar: AppBar(title: const Text('비교 · 타임랩스')),
      body: capturesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오기 오류: $e')),
        data: (captures) {
          if (captures.length < 2) return const _NeedMore();
          // repository는 최신순(desc) → 타임랩스/비교는 시간순(asc).
          final asc = captures.reversed.toList(growable: false);
          return _content(asc);
        },
      ),
    );
  }

  Widget _content(List<Capture> asc) {
    final first = asc.first;
    final last = asc.last;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text('그때 vs 지금', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        // 내보내기 대상 — RepaintBoundary로 감싸 PNG 캡처(한글 라벨·워터마크 포함).
        RepaintBoundary(
          key: _compareKey,
          child: _CompareCard(first: first, last: last),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _exporting ? null : _shareComparison,
          icon: const Icon(Icons.image_outlined),
          label: const Text('비교 이미지 공유'),
        ),
        const SizedBox(height: 28),
        Text('타임랩스', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          '${asc.length}컷 · 시간순으로 재생됩니다',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        TimelapsePlayer(framesAsc: asc),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _exporting ? null : () => _shareTimelapse(asc),
          icon: _exporting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.movie_creation_outlined),
          label: Text(_exporting ? '만드는 중…' : '타임랩스 GIF 공유'),
        ),
      ],
    );
  }

  Future<void> _shareComparison() async {
    setState(() => _exporting = true);
    try {
      final share = ref.read(shareServiceProvider);
      final path = await share.captureBoundaryToPng(_compareKey);
      await share.shareFiles(
        [path],
        text: '그날 우리 — 매달 한 컷, 그날의 우리',
      );
    } catch (e) {
      _showError('비교 이미지 공유에 실패했어요: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _shareTimelapse(List<Capture> asc) async {
    setState(() => _exporting = true);
    try {
      final timelapse = ref.read(timelapseServiceProvider);
      final share = ref.read(shareServiceProvider);
      final frames = asc
          .map((c) => TimelapseFrame(
                imagePath: c.filePath,
                align: c.alignmentMeta != null
                    ? AlignmentMeta.fromMap(c.alignmentMeta!)
                    : AlignmentMeta.identity,
              ))
          .toList(growable: false);

      final gifPath = await timelapse.buildGif(frames);

      // ── 생성 완료: 6-1장이 허용하는 유일한 전면 광고 지점(자연스러운 휴지점).
      //    실제 AdMob 전면 노출은 작업 #9에서 빈도 상한과 함께 연동.
      //    (촬영·비교 뷰에는 광고 금지 — AdPlacement enum에 아예 없음.)

      await share.shareFiles(
        [gifPath],
        text: '그날 우리 — 우리 가족의 ${asc.length}컷 타임랩스',
      );
    } catch (e) {
      _showError('타임랩스 생성에 실패했어요: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// "그때 vs 지금" 비교 카드 — 내보내기 이미지로도 그대로 캡처된다.
class _CompareCard extends StatelessWidget {
  const _CompareCard({required this.first, required this.last});

  final Capture first;
  final Capture last;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _Side(capture: first, caption: '그때')),
              const SizedBox(width: 8),
              Expanded(child: _Side(capture: last, caption: '지금')),
            ],
          ),
          const SizedBox(height: 10),
          // 워터마크(옵션, ⑥장) — 공유 이미지 끝에 브랜드 노출(바이럴 루프).
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_outlined, size: 14, color: scheme.primary),
              const SizedBox(width: 4),
              Text(
                '그날 우리',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({required this.capture, required this.caption});

  final Capture capture;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final file = File(capture.filePath);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: file.existsSync()
                ? Image.file(file, fit: BoxFit.cover)
                : Container(
                    color: scheme.surface,
                    child: Icon(Icons.image_not_supported_outlined,
                        color: scheme.onSurfaceVariant),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          caption,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        Text(
          capture.periodLabel,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// 사진이 2장 미만일 때 안내(비교/타임랩스는 최소 2컷 필요).
class _NeedMore extends StatelessWidget {
  const _NeedMore();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_motion_outlined,
                size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('아직 비교할 게 없어요',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '사진이 2컷 이상 쌓이면\n그때와 지금을 나란히 보고 타임랩스를 만들 수 있어요.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../services/providers.dart';
import '../../services/timelapse/timelapse_service.dart';
import '../../core/utils/age_label.dart';
import '../capture/alignment_meta.dart';
import '../home/home_providers.dart';
import 'collage_poster_screen.dart';
import 'onion_skin_screen.dart';
import 'widgets/timelapse_player.dart';

/// ⑤ 비교 / 타임랩스 — "가치 실현 순간"(변화 체감).
///
/// 구성: ① 그때 vs 지금 비교 뷰(기간 라벨) → 비교 이미지로 내보내기,
/// ② 인앱 타임랩스 재생, ③ 타임랩스 GIF 생성·공유(⑥ 바이럴 루프).
///
/// 광고 규칙(6-1장): 이 화면은 **감정의 정점(비교 뷰)** 이므로 광고를 넣지 않는다.
/// 전면 광고는 오직 타임랩스 "생성 완료" 직후의 자연스러운 휴지점에서만 허용
/// (실제 AdMob 연동은 작업 #9 — 아래 생성 완료 지점에 훅만 표시).
/// 비교·타임랩스를 독립 화면으로 띄울 때 쓰는 얇은 래퍼(상세/알림에서 push).
/// 탭(MainShell)에서는 [CompareView] 본문만 직접 사용한다.
class CompareScreen extends StatelessWidget {
  const CompareScreen({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('비교 · 타임랩스')),
      body: CompareView(project: project),
    );
  }
}

/// 비교/타임랩스 본문(Scaffold 없음 — 탭/화면 양쪽에서 재사용).
class CompareView extends ConsumerStatefulWidget {
  const CompareView({super.key, required this.project});

  final Project project;

  @override
  ConsumerState<CompareView> createState() => _CompareViewState();
}

class _CompareViewState extends ConsumerState<CompareView> {
  final _compareKey = GlobalKey();
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final capturesAsync = ref.watch(capturesProvider(widget.project.id));

    return capturesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('불러오기 오류: $e')),
      data: (captures) {
        if (captures.length < 2) return const _NeedMore();
        // repository는 최신순(desc) → 타임랩스/비교는 시간순(asc).
        final asc = captures.reversed.toList(growable: false);
        return _content(asc);
      },
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
          child: _CompareCard(
            first: first,
            last: last,
            birthday: ref.watch(appSettingsProvider).value?.projectBirthdays[
                widget.project.id],
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _exporting ? null : _shareComparison,
          icon: const Icon(Icons.image_outlined),
          label: const Text('비교 이미지 공유'),
        ),
        const SizedBox(height: 28),
        Text('밀어서 변화 보기', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          '슬라이더를 움직이면 시간이 은은하게 흘러가요',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        _CompareScrubber(framesAsc: asc),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OnionSkinScreen(project: widget.project),
            ),
          ),
          icon: const Icon(Icons.layers_outlined),
          label: const Text('변화의 잔상 보기'),
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
        const SizedBox(height: 28),
        Text('성장 포스터', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          '모든 컷을 한 장으로 묶어 인쇄·공유',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CollagePosterScreen(project: widget.project),
            ),
          ),
          icon: const Icon(Icons.grid_view_rounded),
          label: const Text('성장 포스터 만들기'),
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
  const _CompareCard({
    required this.first,
    required this.last,
    this.birthday,
  });

  final Capture first;
  final Capture last;
  final DateTime? birthday;

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
              Expanded(
                  child: _Side(capture: first, caption: '그때', birthday: birthday)),
              const SizedBox(width: 8),
              Expanded(
                  child: _Side(capture: last, caption: '지금', birthday: birthday)),
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
  const _Side({required this.capture, required this.caption, this.birthday});

  final Capture capture;
  final String caption;
  final DateTime? birthday;

  @override
  Widget build(BuildContext context) {
    final file = File(capture.filePath);
    final scheme = Theme.of(context).colorScheme;
    final age =
        birthday != null ? AgeLabel.format(birthday!, capture.capturedAt) : null;
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
        if (age != null)
          Text(
            age,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
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

/// 아이디어2 — 인터랙티브 비교 스크러버. 슬라이더를 끌면 두 시점이 겹치며
/// 은은하게 모핑(같은 구도라면 변화가 한 화면에서 드러난다).
class _CompareScrubber extends StatefulWidget {
  const _CompareScrubber({required this.framesAsc});
  final List<Capture> framesAsc;

  @override
  State<_CompareScrubber> createState() => _CompareScrubberState();
}

class _CompareScrubberState extends State<_CompareScrubber> {
  late double _t = (widget.framesAsc.length - 1).toDouble();

  @override
  Widget build(BuildContext context) {
    final frames = widget.framesAsc;
    final maxIndex = frames.length - 1;
    final lower = _t.floor().clamp(0, maxIndex);
    final upper = _t.ceil().clamp(0, maxIndex);
    final frac = _t - lower;
    final shown = frac < 0.5 ? lower : upper;

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: LayoutBuilder(
              builder: (context, c) {
                final size = Size(c.maxWidth, c.maxHeight);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: Colors.black),
                    Opacity(
                      opacity: 1 - frac,
                      child: _ScrubPhoto(capture: frames[lower], viewSize: size),
                    ),
                    Opacity(
                      opacity: frac,
                      child: _ScrubPhoto(capture: frames[upper], viewSize: size),
                    ),
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          frames[shown].periodLabel,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        Slider(
          value: _t.clamp(0, maxIndex.toDouble()),
          min: 0,
          max: maxIndex.toDouble(),
          onChanged: (v) => setState(() => _t = v),
        ),
      ],
    );
  }
}

class _ScrubPhoto extends StatelessWidget {
  const _ScrubPhoto({required this.capture, required this.viewSize});
  final Capture capture;
  final Size viewSize;

  @override
  Widget build(BuildContext context) {
    final file = File(capture.filePath);
    if (!file.existsSync()) return const ColoredBox(color: Colors.black12);
    final align = capture.alignmentMeta != null
        ? AlignmentMeta.fromMap(capture.alignmentMeta!)
        : AlignmentMeta.identity;
    final image = Image.file(file, fit: BoxFit.cover, gaplessPlayback: true);
    if (align.isIdentity) return image;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..translateByDouble(
            align.dx * viewSize.width, align.dy * viewSize.height, 0, 1)
        ..rotateZ(align.rotation)
        ..scaleByDouble(align.scale, align.scale, 1, 1),
      child: image,
    );
  }
}

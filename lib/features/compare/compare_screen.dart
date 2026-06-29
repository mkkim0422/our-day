import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../services/providers.dart';
import '../../services/timelapse/timelapse_service.dart';
import '../../core/utils/age_label.dart';
import '../../data/repositories/providers.dart';
import '../capture/alignment_meta.dart';
import '../capture/backfill_screen.dart';
import '../capture/capture_screen.dart';
import '../home/home_providers.dart';
import 'collage_poster_screen.dart';
import 'growth_chart_screen.dart';
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

  // 구성원 필터(아이디어7): null이면 전체.
  String? _filterMemberId;
  Set<String>? _filterCaptureIds;

  // '그때 vs 지금'에 쓸 두 시점(사용자가 직접 선택). null이면 첫↔최신 기본값.
  String? _thenId;
  String? _nowId;

  Future<void> _selectMember(String? memberId) async {
    if (memberId == null) {
      setState(() {
        _filterMemberId = null;
        _filterCaptureIds = null;
      });
      return;
    }
    final ids =
        await ref.read(memberRepositoryProvider).captureIdsForMember(memberId);
    if (mounted) {
      setState(() {
        _filterMemberId = memberId;
        _filterCaptureIds = ids;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final capturesAsync = ref.watch(capturesProvider(widget.project.id));

    return capturesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('불러오기 오류: $e')),
      data: (captures) {
        if (captures.length < 2) return _NeedMore(project: widget.project);
        // repository는 최신순(desc) → 타임랩스/비교는 시간순(asc).
        final asc = captures.reversed.toList(growable: false);
        return _content(asc);
      },
    );
  }

  Widget _content(List<Capture> ascAll) {
    final members = ref.watch(membersProvider(widget.project.id)).value ?? const [];
    // 구성원 필터 적용.
    final asc = _filterCaptureIds == null
        ? ascAll
        : ascAll.where((c) => _filterCaptureIds!.contains(c.id)).toList();

    if (asc.length < 2) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (members.isNotEmpty) _memberFilter(members),
          const SizedBox(height: 40),
          Center(
            child: Text(
              '이 구성원이 태그된 사진이 2컷 미만이에요.\n다른 구성원이나 전체를 선택해 보세요.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      );
    }

    // 기본은 첫↔최신, 사용자가 고른 두 시점이 있으면 그걸 사용(없거나 필터로
    // 사라졌으면 자동으로 첫/최신으로 폴백).
    final thenCap = asc.firstWhere((c) => c.id == _thenId, orElse: () => asc.first);
    final nowCap = asc.firstWhere((c) => c.id == _nowId, orElse: () => asc.last);
    final birthday =
        ref.watch(appSettingsProvider).value?.projectBirthdays[widget.project.id];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (members.isNotEmpty) ...[
          _memberFilter(members),
          const SizedBox(height: 16),
        ],
        // ── 히어로: 타임랩스(가장 핵심) + 1차 액션 한 개.
        Text('${asc.length}컷, 우리 이야기',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        TimelapsePlayer(framesAsc: asc),
        const SizedBox(height: 6),
        Text(
          '타임랩스는 자연스러운 흐름을 위해 꾸미기 전 원본으로 이어져요.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _exporting ? null : () => _shareTimelapse(asc),
          icon: _exporting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.ios_share),
          label: Text(_exporting ? '만드는 중…' : '타임랩스 공유하기'),
        ),
        const SizedBox(height: 8),
        // 공유(다른 앱)와 별개로, 사용자가 가장 기대하는 "내 사진첩에 저장"(⑦).
        OutlinedButton.icon(
          onPressed: _exporting ? null : () => _saveTimelapse(asc),
          icon: const Icon(Icons.download_rounded),
          label: const Text('기기에 저장'),
        ),
        const SizedBox(height: 32),
        // ── 그때 vs 지금(공유 이미지). 두 시점은 탭해서 직접 고를 수 있다.
        Text('그때 vs 지금',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          '사진을 탭하면 비교할 두 시점을 바꿀 수 있어요.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        // RepaintBoundary 안(=공유/저장 이미지)에는 탭 안내 같은 부가 UI를 넣지
        // 않는다(깨끗한 결과물). 선택 동작은 _Side의 GestureDetector로만.
        RepaintBoundary(
          key: _compareKey,
          child: _CompareCard(
            first: thenCap,
            last: nowCap,
            birthday: birthday,
            onPickThen: () => _pickCompareSide(asc, isThen: true),
            onPickNow: () => _pickCompareSide(asc, isThen: false),
          ),
        ),
        const SizedBox(height: 32),
        // ── 더 보기(부가 도구는 깔끔한 메뉴로 정리 — 1차 액션은 위 타임랩스 하나).
        Text('더 보기',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        _MenuCard(rows: [
          _MenuRow(
            icon: Icons.image_outlined,
            title: '이미지로 만들기',
            subtitle: '그때 vs 지금 · 전체 포스터 — 공유/저장',
            onTap: _exporting ? null : _showImageExportSheet,
          ),
          _MenuRow(
            icon: Icons.swipe_outlined,
            title: '밀어서 비교',
            subtitle: '슬라이더로 시간을 넘겨요',
            onTap: () => _push(ScrubberScreen(project: widget.project)),
          ),
          _MenuRow(
            icon: Icons.show_chart,
            title: '성장 차트',
            subtitle: '키 변화를 그래프로',
            onTap: () => _push(GrowthChartScreen(project: widget.project)),
          ),
        ]),
      ],
    );
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  /// '그때'/'지금'에 쓸 사진을 목록에서 직접 고른다(4장 이상이어도 원하는 두 시점 비교).
  Future<void> _pickCompareSide(List<Capture> asc,
      {required bool isThen}) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(isThen ? '‘그때’로 쓸 사진' : '‘지금’으로 쓸 사진',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final c in asc)
                    ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: File(c.thumbPath).existsSync()
                              ? Image.file(File(c.thumbPath), fit: BoxFit.cover)
                              : const ColoredBox(color: Colors.black12),
                        ),
                      ),
                      title: Text(c.periodLabel),
                      trailing: (isThen ? _thenId : _nowId) == c.id
                          ? Icon(Icons.check_circle,
                              color: Theme.of(ctx).colorScheme.primary)
                          : null,
                      onTap: () => Navigator.of(ctx).pop(c.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isThen) {
          _thenId = picked;
        } else {
          _nowId = picked;
        }
      });
    }
  }

  /// 이미지 내보내기 통합 시트 — 그때 vs 지금(공유/저장)과 전체 포스터를 한곳에서.
  void _showImageExportSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.compare_arrows),
              title: const Text('그때 vs 지금 — 공유'),
              subtitle: const Text('선택한 두 시점을 한 장으로'),
              onTap: () {
                Navigator.of(ctx).pop();
                _shareComparison();
              },
            ),
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: const Text('그때 vs 지금 — 저장'),
              subtitle: const Text('사진첩(갤러리)에 저장'),
              onTap: () {
                Navigator.of(ctx).pop();
                _saveComparison();
              },
            ),
            ListTile(
              leading: const Icon(Icons.grid_view_rounded),
              title: const Text('전체 포스터'),
              subtitle: const Text('모든 컷을 한 장 이미지로 모아 인쇄·공유'),
              onTap: () {
                Navigator.of(ctx).pop();
                _push(CollagePosterScreen(project: widget.project));
              },
            ),
          ],
        ),
      ),
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

  /// 비교 이미지를 기기 사진첩에 저장(⑦).
  Future<void> _saveComparison() async {
    setState(() => _exporting = true);
    try {
      final share = ref.read(shareServiceProvider);
      final path = await share.captureBoundaryToPng(_compareKey);
      await share.saveToGallery(path);
      _showInfo('비교 이미지를 사진첩에 저장했어요.');
    } catch (e) {
      _showError('비교 이미지 저장에 실패했어요: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  List<TimelapseFrame> _frames(List<Capture> asc) => asc
      .map((c) => TimelapseFrame(
            imagePath: c.filePath,
            align: c.alignmentMeta != null
                ? AlignmentMeta.fromMap(c.alignmentMeta!)
                : AlignmentMeta.identity,
          ))
      .toList(growable: false);

  Future<void> _shareTimelapse(List<Capture> asc) async {
    setState(() => _exporting = true);
    try {
      final timelapse = ref.read(timelapseServiceProvider);
      final share = ref.read(shareServiceProvider);
      final gifPath = await timelapse.buildGif(_frames(asc));

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

  /// 타임랩스 GIF를 기기 사진첩에 저장(⑦).
  Future<void> _saveTimelapse(List<Capture> asc) async {
    setState(() => _exporting = true);
    try {
      final timelapse = ref.read(timelapseServiceProvider);
      final share = ref.read(shareServiceProvider);
      final gifPath = await timelapse.buildGif(_frames(asc));
      await share.saveToGallery(gifPath);
      _showInfo('타임랩스를 사진첩에 저장했어요.');
    } catch (e) {
      _showError('타임랩스 저장에 실패했어요: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// 구성원 필터 칩(전체 + 각 구성원). 선택 시 그 구성원이 태그된 컷만 본다.
  Widget _memberFilter(List<Member> members) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('전체'),
              selected: _filterMemberId == null,
              onSelected: (_) => _selectMember(null),
            ),
          ),
          for (final m in members)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(m.name),
                selected: _filterMemberId == m.id,
                onSelected: (_) => _selectMember(m.id),
              ),
            ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showInfo(String msg) {
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
    this.onPickThen,
    this.onPickNow,
  });

  final Capture first;
  final Capture last;
  final DateTime? birthday;
  final VoidCallback? onPickThen;
  final VoidCallback? onPickNow;

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
                  child: _Side(
                      capture: first,
                      caption: '그때',
                      birthday: birthday,
                      onTap: onPickThen)),
              const SizedBox(width: 8),
              Expanded(
                  child: _Side(
                      capture: last,
                      caption: '지금',
                      birthday: birthday,
                      onTap: onPickNow)),
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
  const _Side(
      {required this.capture,
      required this.caption,
      this.birthday,
      this.onTap});

  final Capture capture;
  final String caption;
  final DateTime? birthday;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // 꾸민 버전이 있으면 비교 카드에도 꾸민 사진을 보여준다(앨범과 일관).
    final file = File(capture.decoratedPath ?? capture.filePath);
    final scheme = Theme.of(context).colorScheme;
    final age =
        birthday != null ? AgeLabel.format(birthday!, capture.capturedAt) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 탭하면 이 시점을 다른 사진으로 교체(공유 이미지에는 안 보이는 동작).
        GestureDetector(
          onTap: onTap,
          child: AspectRatio(
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
  const _NeedMore({required this.project});
  final Project project;

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
            Text('아직 추억 영상을 만들 수 없어요',
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
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => CaptureScreen(project: project)),
              ),
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('지금 한 컷 찍기'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => BackfillScreen(project: project)),
              ),
              icon: const Icon(Icons.library_add_outlined),
              label: const Text('예전 사진으로 채우기'),
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

/// "밀어서 변화 보기" 단독 화면(비교 화면 메뉴에서 진입).
class ScrubberScreen extends ConsumerWidget {
  const ScrubberScreen({super.key, required this.project});
  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capturesAsync = ref.watch(capturesProvider(project.id));
    return Scaffold(
      appBar: AppBar(title: const Text('밀어서 비교')),
      body: capturesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오기 오류: $e')),
        data: (captures) {
          if (captures.length < 2) {
            return const Center(child: Text('사진이 2컷 이상이면 볼 수 있어요.'));
          }
          final asc = captures.reversed.toList(growable: false);
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [_CompareScrubber(framesAsc: asc)],
            ),
          );
        },
      ),
    );
  }
}

/// 토스풍 메뉴 카드(둥근 흰 카드 안에 행들).
class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.rows});
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(height: 1, indent: 56, color: scheme.outlineVariant),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: scheme.primary),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(subtitle,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
      trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
    );
  }
}

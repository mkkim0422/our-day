import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../../data/db/app_database.dart';
import '../../data/repositories/providers.dart';
import '../../services/gallery/similar_photo_finder.dart';
import '../../services/providers.dart';

/// 검색 화면 단계.
enum _Phase { surveying, ready, scanning, results, denied, failed }

/// 갤러리에서 **기준 사진과 비슷한 사진**을 찾아 한 번에 가져오기.
/// 같은 포즈·장소·구도를 자동으로 골라 빈 기간을 채운다(지각 해시 기반).
class SimilarPhotosScreen extends ConsumerStatefulWidget {
  const SimilarPhotosScreen({
    super.key,
    required this.project,
    required this.referencePath,
    this.limitedAccess = false,
  });

  final Project project;

  /// 기준 사진 경로(이 사진과 비슷한 걸 찾는다).
  final String referencePath;

  /// '일부 사진만 허용' 상태 — 결과 위에 전체 허용 안내 배너를 띄운다.
  final bool limitedAccess;

  @override
  ConsumerState<SimilarPhotosScreen> createState() =>
      _SimilarPhotosScreenState();
}

class _SimilarPhotosScreenState extends ConsumerState<SimilarPhotosScreen> {
  // 화면 단계: 조사(카운트·속도측정) → 준비(예측·확인) → 검색 → 결과 / 거부 / 실패.
  _Phase _phase = _Phase.surveying;
  GallerySurvey? _survey;

  bool _cancel = false; // '중지' 누름 → 검색을 안전하게 멈춤.
  double _progress = 0;
  int _scanned = 0;
  int _planned = 0;
  final Stopwatch _watch = Stopwatch();

  List<SimilarMatch> _matches = const [];
  final Set<String> _selected = {};
  bool _importing = false;
  Uint8List? _refBytes;

  @override
  void initState() {
    super.initState();
    _runSurvey();
  }

  /// 권한 확인 → 기준 사진 로드 → 갤러리 조사(총 장수 + 장당 속도) → 예측 표시.
  Future<void> _runSurvey() async {
    setState(() => _phase = _Phase.surveying);
    final finder = ref.read(similarPhotoFinderProvider);
    if (!await finder.ensurePermission()) {
      if (mounted) setState(() => _phase = _Phase.denied);
      return;
    }
    final refFile = File(widget.referencePath);
    if (!refFile.existsSync()) {
      if (mounted) setState(() => _phase = _Phase.failed);
      return;
    }
    try {
      _refBytes = refFile.readAsBytesSync();
      final survey = await finder.survey();
      if (!mounted) return;
      setState(() {
        _survey = survey;
        _phase = survey.hasPhotos ? _Phase.ready : _Phase.failed;
      });
    } catch (e) {
      debugPrint('[similar] survey error: $e');
      if (mounted) setState(() => _phase = _Phase.failed);
    }
  }

  /// 사용자가 동의한 장수[count]로 실제 검색 시작. 진행률·남은시간 표시, 중지 가능.
  Future<void> _start(int count) async {
    final bytes = _refBytes;
    if (bytes == null) return;
    final finder = ref.read(similarPhotoFinderProvider);
    setState(() {
      _phase = _Phase.scanning;
      _cancel = false;
      _progress = 0;
      _scanned = 0;
      _planned = count;
      _matches = const [];
    });
    _watch
      ..reset()
      ..start();
    try {
      final matches = await finder.findSimilar(
        bytes,
        scanLimit: count,
        isCancelled: () => _cancel,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onScanned: (scanned, planned) {
          if (mounted) {
            setState(() {
              _scanned = scanned;
              _planned = planned;
            });
          }
        },
        // 1차 결과가 나오는 즉시 그리드를 띄운다 — 빈 화면에 갇히지 않게.
        onPartial: (partial) {
          if (mounted) setState(() => _matches = partial);
        },
      );
      _watch.stop();
      if (mounted) {
        setState(() {
          _matches = matches;
          _phase = _Phase.results;
        });
      }
    } catch (e) {
      _watch.stop();
      debugPrint('[similar] scan error: $e');
      if (mounted) {
        setState(() =>
            _phase = _matches.isEmpty ? _Phase.failed : _Phase.results);
      }
    }
  }

  /// 남은 시간 추정(진행률 기반). 표시용 근사치.
  String _etaLabel() {
    final p = _progress;
    if (p < 0.03) return '잠시만 기다려 주세요';
    final remainMs = (_watch.elapsedMilliseconds * (1 - p) / p).round();
    final s = (remainMs / 1000).round();
    if (s <= 1) return '거의 다 됐어요';
    if (s < 60) return '약 $s초 남음';
    return '약 ${(s / 60).ceil()}분 남음';
  }

  String _fmtDuration(Duration d) {
    final s = d.inSeconds;
    if (s < 60) return '약 $s초';
    return '약 ${(s / 60).ceil()}분';
  }

  /// 천 단위 콤마.
  String _comma(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  Future<void> _import() async {
    if (_selected.isEmpty || _importing) return;
    setState(() => _importing = true);
    final storage = ref.read(photoStorageProvider);
    final captures = ref.read(captureRepositoryProvider);
    var added = 0;
    var failed = 0;
    try {
      for (final m in _matches.where((m) => _selected.contains(m.asset.id))) {
        try {
          final file = await m.asset.file;
          if (file == null) {
            failed++;
            continue;
          }
          final stored = await storage.saveFromFile(file.path);
          await captures.create(
            project: widget.project,
            filePath: stored.originalPath,
            thumbPath: stored.thumbPath,
            // 찍힌 날짜로 저장 → 알맞은 기간에 자동으로 채워짐.
            capturedAt: m.asset.createDateTime,
          );
          added++;
        } catch (_) {
          failed++;
        }
      }
      if (added > 0) {
        final all = await captures.listByProject(widget.project.id);
        final birthday = ref
            .read(appSettingsProvider)
            .value
            ?.projectBirthdays[widget.project.id];
        await ref
            .read(notificationServiceProvider)
            .scheduleForProject(widget.project, all, birthday: birthday);
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
    if (!mounted) return;
    // 한 장도 못 넣었으면 화면을 닫지 않고 안내(다시 시도할 수 있게).
    if (added == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 추가하지 못했어요. 다시 시도해 주세요.')),
      );
      return;
    }
    if (failed > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$added장 추가 완료 ($failed장은 실패해 건너뜀)')),
      );
    }
    Navigator.of(context).pop(added);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('비슷한 사진 가져오기')),
      body: _body(),
      bottomNavigationBar: _bottomBar(),
    );
  }

  /// 단계별 하단 버튼: 검색 중엔 '중지', 결과가 있으면 '가져오기'.
  Widget? _bottomBar() {
    if (_phase == _Phase.scanning) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52)),
            onPressed: _cancel ? null : () => setState(() => _cancel = true),
            icon: const Icon(Icons.stop_circle_outlined),
            label: Text(_cancel ? '마무리하는 중…' : '여기까지만 찾기 (중지)'),
          ),
        ),
      );
    }
    if (_phase == _Phase.results && _matches.isNotEmpty) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: (_selected.isEmpty || _importing) ? null : _import,
            icon: _importing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.download_rounded),
            label: Text(_importing
                ? '가져오는 중…'
                : (_selected.isEmpty
                    ? '사진을 선택해 주세요'
                    : '${_selected.length}장 가져오기')),
          ),
        ),
      );
    }
    return null;
  }

  Widget _body() {
    switch (_phase) {
      case _Phase.denied:
        return _info(
          Icons.no_photography_outlined,
          '사진 접근 권한이 필요해요',
          '비슷한 사진을 찾으려면 사진 보관함 접근을 허용해 주세요.',
          action: FilledButton(
            onPressed: PhotoManager.openSetting,
            child: const Text('설정 열기'),
          ),
        );
      case _Phase.failed:
        return _info(
          Icons.error_outline,
          '검색을 끝내지 못했어요',
          '잠시 후 다시 시도하거나, 다른 기준 사진으로 시도해 주세요.',
          action: FilledButton(
            onPressed: _runSurvey,
            child: const Text('다시 시도'),
          ),
        );
      case _Phase.surveying:
        return _spinner('사진을 확인하는 중…');
      case _Phase.ready:
        return _ready();
      case _Phase.scanning:
        return _scanning();
      case _Phase.results:
        if (_matches.isEmpty) {
          return _info(Icons.search_off, '비슷한 자세의 사진을 찾지 못했어요',
              '인물의 자세가 또렷하게 나온 사진으로 다시 시도하거나, 직접 골라서 채워보세요.');
        }
        return Column(
          children: [
            if (widget.limitedAccess) _limitedBanner(),
            Expanded(child: _grid()),
          ],
        );
    }
  }

  Widget _spinner(String label) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(label,
              style: TextStyle(
                  color: scheme.onSurface, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  /// 준비 화면 — 사진 수 + 예상 시간 + '빠른/전체 검색' 선택.
  Widget _ready() {
    final s = _survey!;
    final scheme = Theme.of(context).colorScheme;
    final quickOnly = s.total <= s.quickCount; // 작은 갤러리는 한 번에.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_search, size: 56, color: scheme.primary),
            const SizedBox(height: 14),
            Text('사진 ${_comma(s.total)}장을 찾았어요',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text('이 중에서 기준 사진과 비슷한 자세를 모아드려요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            if (quickOnly)
              _startCard(
                title: '검색 시작',
                subtitle:
                    '예상 ${_fmtDuration(s.quickEstimate)} · 언제든 중지할 수 있어요',
                highlight: true,
                onTap: () => _start(s.quickCount),
              )
            else ...[
              _startCard(
                title: '빠른 검색  ·  추천',
                subtitle:
                    '대표 구간 ${_comma(s.quickCount)}장 · 예상 ${_fmtDuration(s.quickEstimate)}',
                highlight: true,
                onTap: () => _start(s.quickCount),
              ),
              const SizedBox(height: 12),
              _startCard(
                title: '전체 검색',
                subtitle:
                    '모든 기간 ${_comma(s.fullCount)}장 · 예상 ${_fmtDuration(s.fullEstimate)} · 더 많이 찾아요',
                highlight: false,
                onTap: () => _start(s.fullCount),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _startCard({
    required String title,
    required String subtitle,
    required bool highlight,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final fg = highlight ? scheme.onPrimaryContainer : scheme.onSurface;
    return Material(
      color:
          highlight ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: fg)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 13, color: fg.withValues(alpha: 0.85))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: fg),
            ],
          ),
        ),
      ),
    );
  }

  /// 검색 진행 화면 — 진행률·남은시간 + 도중 결과 미리보기.
  Widget _scanning() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progress <= 0 ? null : _progress,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 10),
              Text('${_comma(_scanned)} / ${_comma(_planned)}장에서 자세 비교 중',
                  style: TextStyle(
                      color: scheme.onSurface, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('${(_progress * 100).round()}%  ·  ${_etaLabel()}',
                  style:
                      TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
            ],
          ),
        ),
        if (_matches.isNotEmpty)
          Expanded(child: _grid())
        else
          const Expanded(child: SizedBox.shrink()),
      ],
    );
  }

  Widget _grid() {
    final scheme = Theme.of(context).colorScheme;
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _matches.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, i) {
        final m = _matches[i];
        final selected = _selected.contains(m.asset.id);
        return GestureDetector(
          onTap: () => setState(() {
            selected ? _selected.remove(m.asset.id) : _selected.add(m.asset.id);
          }),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image(
                  image: AssetEntityImageProvider(m.asset,
                      isOriginal: false,
                      thumbnailSize: const ThumbnailSize.square(220)),
                  fit: BoxFit.cover,
                ),
                if (selected)
                  Container(
                    color: scheme.primary.withValues(alpha: 0.35),
                    alignment: Alignment.center,
                    child: const Icon(Icons.check_circle,
                        color: Colors.white, size: 28),
                  ),
                Positioned(
                  left: 4,
                  bottom: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${(m.similarity * 100).round()}%',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// '일부 사진만 허용' 안내 배너 — 탭하면 설정으로 이동해 전체 허용.
  Widget _limitedBanner() {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      child: InkWell(
        onTap: PhotoManager.openSetting,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Icon(Icons.info_outline,
                  size: 20, color: scheme.onSecondaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '일부 사진만 허용되어 있어요. 더 많은 결과를 보려면 ‘모든 사진’을 허용하세요.',
                  style: TextStyle(
                      color: scheme.onSecondaryContainer, fontSize: 13),
                ),
              ),
              Text('설정',
                  style: TextStyle(
                      color: scheme.primary, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _info(IconData icon, String title, String body, {Widget? action}) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(body,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant)),
            if (action != null) ...[const SizedBox(height: 16), action],
          ],
        ),
      ),
    );
  }
}

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import 'gallery_scan_service.dart';
import 'story_engine.dart';
import 'story_models.dart';

/// 스토리 기능 검증용 **미리보기**(POC). 갤러리를 스캔해 [StoryEngine]이 어떤
/// 스토리를 뽑는지 보여주고, **기준을 슬라이더로 조절**하며 결과 변화를 확인한다.
/// 스토리를 탭하면 안에 묶인 사진을 직접 열어볼 수 있다(UI/BGM/영상은 없음).
class StoryPreviewScreen extends StatefulWidget {
  const StoryPreviewScreen({super.key});

  @override
  State<StoryPreviewScreen> createState() => _StoryPreviewScreenState();
}

class _StoryPreviewScreenState extends State<StoryPreviewScreen> {
  final _scanner = const GalleryScanService();

  bool _loading = true;
  bool _denied = false;
  String? _error;
  int _progress = 0;
  int _progressTotal = 0;

  GalleryScanResult? _result;
  List<StoryPhoto> _photos = const [];
  List<Story> _stories = const [];

  // 조절 가능한 기준(미리보기에서 직접 낮춰보며 확인).
  double _tripMin = 4;
  double _dayMin = 5;
  double _monthMin = 8;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _denied = false;
      _error = null;
      _progress = 0;
      _progressTotal = 0;
    });
    try {
      final perm = await _scanner.requestPermission();
      if (!perm.hasAccess) {
        setState(() {
          _loading = false;
          _denied = true;
        });
        return;
      }
      final result = await _scanner.scanRecent(
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() {
            _progress = done;
            _progressTotal = total;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _photos = result.photos;
        _loading = false;
      });
      _recompute();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  /// 스캔은 그대로 두고 기준만 바꿔 엔진을 다시 돌린다(빠름).
  void _recompute() {
    final engine = StoryEngine(StoryConfig(
      minTripPhotos: _tripMin.round(),
      minDayPhotos: _dayMin.round(),
      minMonthPhotos: _monthMin.round(),
    ));
    setState(() => _stories = engine.generate(_photos, now: DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('스토리 미리보기 (베타)'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _run,
            icon: const Icon(Icons.refresh),
            tooltip: '다시 스캔',
          ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      final pct = _progressTotal == 0 ? 0 : (_progress * 100 ~/ _progressTotal);
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_progressTotal == 0
                ? '갤러리를 여는 중…'
                : '사진 확인 중  $_progress / $_progressTotal  ($pct%)'),
            const SizedBox(height: 4),
            const Text('위치 정보까지 읽느라 조금 걸려요',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }
    if (_denied) {
      return _message(
        icon: Icons.lock_outline,
        title: '사진 접근 권한이 필요해요',
        body: '스토리를 만들려면 갤러리 사진을 읽어야 해요. 설정에서 허용해 주세요.',
        action: FilledButton(
          onPressed: PhotoManager.openSetting,
          child: const Text('설정 열기'),
        ),
      );
    }
    if (_error != null) {
      return _message(
          icon: Icons.error_outline, title: '스캔 중 오류가 났어요', body: _error!);
    }

    final diag = _Diagnostics.from(_photos);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _summaryCard(_result!, diag),
        const SizedBox(height: 16),
        _controls(diag),
        const SizedBox(height: 16),
        if (_stories.isEmpty)
          _emptyExplain(diag)
        else ...[
          _section('🧳 여행', StoryKind.trip,
              '집(사진이 가장 몰린 곳)에서 30km 밖에서 며칠 연속 찍은 사진 묶음.'),
          _section('📅 어느 날', StoryKind.oneDay,
              '하루에 많이 찍은 날(여행에 안 든). 위 ‘어느 날 기준’ 장수 이상.'),
          _section('🗓 월별 모음', StoryKind.monthly,
              '한 달 동안 많이 찍힌 달을 통째로 묶음(예: 2024년 5월).'),
        ],
      ],
    );
  }

  Widget _summaryCard(GalleryScanResult r, _Diagnostics d) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('스캔 진단',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _stat('스캔한 사진', '${r.scanned}장 (전체 ${r.totalInGallery}장 중)'),
          _stat('기간', d.range),
          _stat('위치(GPS) 있는 사진', '${r.withLocation}장'),
          const Divider(height: 18),
          _stat('하루 최대 장수', '${d.maxDay}장'),
          _stat('한 달 최대 장수', '${d.maxMonth}장'),
          _stat('만들어진 스토리', '${_stories.length}개'),
        ],
      ),
    );
  }

  Widget _controls(_Diagnostics d) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text('기준 조절 — 낮출수록 스토리가 더 많이 생겨요',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          _slider('여행 최소 장수', _tripMin, 3, 15, (v) => _tripMin = v),
          _slider('어느 날 최소 장수', _dayMin, 3, 20, (v) => _dayMin = v),
          _slider('월별 모음 최소 장수', _monthMin, 5, 40, (v) => _monthMin = v),
        ],
      ),
    );
  }

  Widget _slider(
      String label, double value, double min, double max, ValueChanged<double> set) {
    return Row(
      children: [
        SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 13))),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).round(),
            label: '${value.round()}장',
            onChanged: (v) {
              set(v);
              _recompute();
            },
          ),
        ),
        SizedBox(
            width: 36,
            child: Text('${value.round()}',
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w700))),
      ],
    );
  }

  Widget _emptyExplain(_Diagnostics d) {
    final scheme = Theme.of(context).colorScheme;
    final reasons = <String>[];
    if (_result!.withLocation == 0) {
      reasons.add('• 위치(GPS) 있는 사진이 0장 → ‘여행’은 절대 안 나와요. '
          '(카톡으로 받은 사진·스크린샷은 위치가 없어요. 직접 카메라로 찍은 사진은 보통 있어요)');
    }
    if (d.maxDay < _dayMin.round()) {
      reasons.add('• 하루 최대 ${d.maxDay}장인데 ‘어느 날 기준’은 ${_dayMin.round()}장 → '
          '기준을 ${d.maxDay}장까지 낮추면 나와요.');
    }
    if (d.maxMonth < _monthMin.round()) {
      reasons.add('• 한 달 최대 ${d.maxMonth}장인데 ‘월별 기준’은 ${_monthMin.round()}장 → '
          '기준을 낮추면 나와요.');
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: scheme.primary),
              const SizedBox(width: 8),
              Text('아직 스토리가 없는 이유',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          if (reasons.isEmpty)
            const Text('기준을 더 낮춰 보세요. 위 슬라이더를 왼쪽으로 옮기면 스토리가 생깁니다.')
          else
            for (final r in reasons)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(r, style: const TextStyle(height: 1.4)),
              ),
        ],
      ),
    );
  }

  Widget _stat(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            Flexible(
                child: Text(v,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );

  Widget _section(String label, StoryKind kind, String desc) {
    final items = _stories.where((s) => s.kind == kind).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 2),
          child: Text(label,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
          child: Text(desc,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
        for (final s in items) _storyTile(s),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _storyTile(Story s) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: _Cover(assetId: s.coverPhotoId, size: 52),
        title:
            Text(s.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(s.subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                _StoryDetailScreen(title: s.title, photoIds: s.photoIds),
          ),
        ),
      ),
    );
  }

  Widget _message({
    required IconData icon,
    required String title,
    required String body,
    Widget? action,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(body,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          if (action != null) ...[const SizedBox(height: 16), action],
        ],
      ),
    );
  }
}

/// 사진 메타데이터에서 뽑은 진단 수치(왜 스토리가 있/없는지 설명용).
class _Diagnostics {
  const _Diagnostics({
    required this.maxDay,
    required this.maxMonth,
    required this.range,
  });

  final int maxDay;
  final int maxMonth;
  final String range;

  factory _Diagnostics.from(List<StoryPhoto> photos) {
    if (photos.isEmpty) {
      return const _Diagnostics(maxDay: 0, maxMonth: 0, range: '-');
    }
    final dayCount = <int, int>{};
    final monthCount = <int, int>{};
    DateTime? min;
    DateTime? max;
    for (final p in photos) {
      final t = p.takenAt;
      final dk = t.year * 10000 + t.month * 100 + t.day;
      final mk = t.year * 100 + t.month;
      dayCount[dk] = (dayCount[dk] ?? 0) + 1;
      monthCount[mk] = (monthCount[mk] ?? 0) + 1;
      if (min == null || t.isBefore(min)) min = t;
      if (max == null || t.isAfter(max)) max = t;
    }
    int maxOf(Map<int, int> m) =>
        m.values.fold(0, (a, b) => a > b ? a : b);
    String d(DateTime t) => '${t.year}.${t.month}.${t.day}';
    return _Diagnostics(
      maxDay: maxOf(dayCount),
      maxMonth: maxOf(monthCount),
      range: '${d(min!)} ~ ${d(max!)}',
    );
  }
}

/// 스토리에 묶인 사진을 그리드로 보여주는 검증 화면(날짜 라벨 포함).
class _StoryDetailScreen extends StatelessWidget {
  const _StoryDetailScreen({required this.title, required this.photoIds});

  final String title;
  final List<String> photoIds;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$title · ${photoIds.length}장')),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.82,
        ),
        itemCount: photoIds.length,
        itemBuilder: (context, i) => _DetailCell(assetId: photoIds[i]),
      ),
    );
  }
}

class _DetailCell extends StatelessWidget {
  const _DetailCell({required this.assetId});
  final String assetId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AssetEntity?>(
      future: AssetEntity.fromId(assetId),
      builder: (context, snap) {
        final asset = snap.data;
        final date = asset?.createDateTime;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _Cover(assetId: assetId, size: 120)),
            const SizedBox(height: 2),
            Text(
              date == null
                  ? ''
                  : '${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }
}

/// 사진 썸네일(asset id → 썸네일 바이트).
class _Cover extends StatelessWidget {
  const _Cover({required this.assetId, required this.size});
  final String assetId;
  final double size;

  Future<Uint8List?> _thumb() async {
    final asset = await AssetEntity.fromId(assetId);
    if (asset == null) return null;
    return asset.thumbnailDataWithSize(const ThumbnailSize(200, 200));
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: FutureBuilder<Uint8List?>(
          future: _thumb(),
          builder: (context, snap) {
            final bytes = snap.data;
            if (bytes == null) {
              return ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(Icons.image_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              );
            }
            return Image.memory(bytes, fit: BoxFit.cover);
          },
        ),
      ),
    );
  }
}

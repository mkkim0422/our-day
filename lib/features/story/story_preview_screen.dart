import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import 'gallery_scan_service.dart';
import 'story_engine.dart';
import 'story_models.dart';

/// 스토리 기능 검증용 **미리보기**(POC). 폰 갤러리를 스캔해 [StoryEngine]이
/// 어떤 스토리를 뽑는지 목록만 보여준다(UI 꾸미기·BGM·영상 없음).
///
/// 묶음이 그럴듯한지 실기기에서 직접 확인하기 위한 화면이다.
class StoryPreviewScreen extends StatefulWidget {
  const StoryPreviewScreen({super.key});

  @override
  State<StoryPreviewScreen> createState() => _StoryPreviewScreenState();
}

class _StoryPreviewScreenState extends State<StoryPreviewScreen> {
  final _scanner = const GalleryScanService();
  final _engine = const StoryEngine();

  bool _loading = true;
  bool _denied = false;
  String? _error;
  GalleryScanResult? _result;
  List<Story> _stories = const [];

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
      final result = await _scanner.scanRecent();
      final stories = _engine.generate(result.photos, now: DateTime.now());
      if (!mounted) return;
      setState(() {
        _result = result;
        _stories = stories;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
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
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('갤러리를 살펴보는 중…'),
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
        icon: Icons.error_outline,
        title: '스캔 중 오류가 났어요',
        body: _error!,
      );
    }

    final r = _result!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _summaryCard(r),
        const SizedBox(height: 16),
        if (_stories.isEmpty)
          _message(
            icon: Icons.auto_stories_outlined,
            title: '아직 만들 스토리가 없어요',
            body: '여행(같은 곳에서 며칠 연속)·하루에 많이 찍은 날·한 달 많이 찍은 달이\n'
                '있으면 자동으로 묶여요. 사진이 더 쌓이면 다시 시도해 보세요.',
          )
        else ...[
          _section('여행', StoryKind.trip),
          _section('어느 날', StoryKind.oneDay),
          _section('이달의 기록', StoryKind.monthly),
        ],
      ],
    );
  }

  Widget _summaryCard(GalleryScanResult r) {
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
          Text('스캔 결과',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _stat('스캔한 사진', '${r.scanned}장 (전체 ${r.totalInGallery}장 중)'),
          _stat('위치(GPS) 있는 사진', '${r.withLocation}장'),
          _stat('만들어진 스토리', '${_stories.length}개'),
          if (r.withLocation == 0) ...[
            const SizedBox(height: 8),
            Text(
              '※ 위치 정보가 있는 사진이 없어 ‘여행’은 안 나올 수 있어요. '
              '(스크린샷·카톡으로 받은 사진은 보통 위치가 없어요)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant),
            ),
          ],
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
            Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _section(String label, StoryKind kind) {
    final items = _stories.where((s) => s.kind == kind).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(label,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
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
        leading: _Cover(assetId: s.coverPhotoId),
        title: Text(s.title,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(s.subtitle),
        trailing: Text('${s.count}장',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
          if (action != null) ...[
            const SizedBox(height: 16),
            action,
          ],
        ],
      ),
    );
  }
}

/// 스토리 대표 사진 썸네일(asset id → 썸네일 바이트).
class _Cover extends StatelessWidget {
  const _Cover({required this.assetId});
  final String assetId;

  Future<Uint8List?> _thumb() async {
    final asset = await AssetEntity.fromId(assetId);
    if (asset == null) return null;
    return asset.thumbnailDataWithSize(const ThumbnailSize(120, 120));
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 52,
        height: 52,
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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../../data/db/app_database.dart';
import '../../data/repositories/providers.dart';
import '../../services/gallery/similar_photo_finder.dart';
import '../../services/providers.dart';

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
  bool _loading = true;
  bool _denied = false;
  double _progress = 0;
  List<SimilarMatch> _matches = const [];
  final Set<String> _selected = {};
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    final finder = ref.read(similarPhotoFinderProvider);
    if (!await finder.ensurePermission()) {
      setState(() {
        _loading = false;
        _denied = true;
      });
      return;
    }
    final refFile = File(widget.referencePath);
    if (!refFile.existsSync()) {
      setState(() => _loading = false);
      return;
    }
    final refBytes = refFile.readAsBytesSync();
    final matches = await finder.findSimilar(
      refBytes,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );
    if (mounted) {
      setState(() {
        _matches = matches;
        _loading = false;
      });
    }
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
      bottomNavigationBar: (_matches.isEmpty || _loading)
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52)),
                  onPressed:
                      (_selected.isEmpty || _importing) ? null : _import,
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
            ),
    );
  }

  Widget _body() {
    final scheme = Theme.of(context).colorScheme;
    if (_denied) {
      return _info(
        Icons.no_photography_outlined,
        '사진 접근 권한이 필요해요',
        '비슷한 사진을 찾으려면 사진 보관함 접근을 허용해 주세요.',
        action: FilledButton(
          onPressed: PhotoManager.openSetting,
          child: const Text('설정 열기'),
        ),
      );
    }
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
                _progress < 0.5
                    ? '갤러리에서 비슷한 사진을 찾는 중…'
                    : '자세(포즈)를 분석하는 중…',
                style: TextStyle(
                    color: scheme.onSurface, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${(_progress * 100).round()}%  ·  잠시만 기다려 주세요',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
          ],
        ),
      );
    }
    if (_matches.isEmpty) {
      return _info(Icons.search_off, '비슷한 자세의 사진을 찾지 못했어요',
          '인물의 자세가 또렷하게 나온 사진을 기준으로 다시 시도하거나,\n직접 골라서 채워보세요.');
    }
    return Column(
      children: [
        if (widget.limitedAccess) _limitedBanner(),
        Expanded(
          child: GridView.builder(
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
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
          ),
        ),
      ],
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

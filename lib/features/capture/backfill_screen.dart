import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'similar_photos_screen.dart';

import '../../core/utils/backfill_dates.dart';
import '../../core/utils/schedule_period.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/providers.dart';
import '../../services/providers.dart';

/// 과거 일괄 채우기 — ②-1 입력경로 3 ("backfill").
///
/// 갤러리에서 예전 가족 사진을 여러 장 골라 **서로 다른 기간**에 한 번에 채운다.
/// 가입 직후 빈 타임라인 문제를 해결하고 "쌓인 결과"를 즉시 체감하게 해 리텐션에
/// 크게 기여(②-1 주석: "리텐션 매우 중요"). 각 사진의 날짜는 프로젝트 주기에 맞춰
/// 과거로 자동 배치되며 개별 수정할 수 있다([BackfillDates]).
class BackfillScreen extends ConsumerStatefulWidget {
  const BackfillScreen({super.key, required this.project});

  final Project project;

  @override
  ConsumerState<BackfillScreen> createState() => _BackfillScreenState();
}

class _BackfillItem {
  _BackfillItem({required this.path, required this.date});
  final String path;
  DateTime date;
}

class _BackfillScreenState extends ConsumerState<BackfillScreen> {
  final _picker = ImagePicker();
  final List<_BackfillItem> _items = [];
  bool _saving = false;
  bool _pickedOnce = false;

  @override
  void initState() {
    super.initState();
    // 진입하자마자 갤러리 다중 선택을 띄워 흐름을 끊지 않는다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
  }

  Future<void> _pick() async {
    final picked = await _picker.pickMultiImage();
    _pickedOnce = true;
    if (picked.isEmpty) {
      if (mounted) setState(() {});
      return;
    }
    // 새로 고른 사진들에 주기 기반 추천 날짜를 부여(기존 항목 뒤로 이어 붙임).
    final suggestions = BackfillDates.suggest(
      widget.project.scheduleType,
      widget.project.scheduleConfig,
      DateTime.now(),
      _items.length + picked.length,
    ).skip(_items.length).toList();

    setState(() {
      for (var i = 0; i < picked.length; i++) {
        _items.add(_BackfillItem(path: picked[i].path, date: suggestions[i]));
      }
    });
  }

  Future<void> _editDate(_BackfillItem item) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: item.date.isAfter(now) ? now : item.date,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => item.date = DateTime(
            picked.year,
            picked.month,
            picked.day,
            12,
          ));
    }
  }

  Future<void> _saveAll() async {
    if (_items.isEmpty || _saving) return;
    setState(() => _saving = true);

    final storage = ref.read(photoStorageProvider);
    final captures = ref.read(captureRepositoryProvider);
    var added = 0;
    var failed = 0;

    try {
      for (final item in _items) {
        // 한 장이 실패해도(예: 클라우드 전용 갤러리 URI) 나머지는 계속 진행.
        try {
          final stored = await storage.saveFromFile(item.path);
          await captures.create(
            project: widget.project,
            filePath: stored.originalPath,
            thumbPath: stored.thumbPath,
            capturedAt: item.date,
          );
          added++;
        } catch (_) {
          failed++;
        }
      }

      // 사진이 쌓이면 회상 알림 대상이 늘어나므로 한 번 재예약(작업 #5 패턴).
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
      if (mounted) setState(() => _saving = false);
    }

    if (!mounted) return;
    if (added == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 추가하지 못했어요. 다른 사진으로 다시 시도해 주세요.')),
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
      appBar: AppBar(
        title: const Text('예전 사진 채우기'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _pick,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('더 고르기'),
          ),
        ],
      ),
      body: _items.isEmpty ? _empty() : _list(),
      bottomNavigationBar: _items.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52)),
                  onPressed: _saving ? null : _saveAll,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(_saving ? '추가 중…' : '${_items.length}장 추가'),
                ),
              ),
            ),
    );
  }

  Widget _empty() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined,
                size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              _pickedOnce ? '선택한 사진이 없어요' : '갤러리를 여는 중…',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '예전 가족 사진을 골라 지난 기간들을 한 번에 채워보세요.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.photo_library),
              label: const Text('갤러리에서 고르기'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _findSimilar,
              icon: const Icon(Icons.image_search),
              label: const Text('비슷한 사진 자동으로 찾기'),
            ),
          ],
        ),
      ),
    );
  }

  /// 기준 사진 한 장을 고르면, 갤러리에서 비슷한(같은 포즈·장소) 사진을 찾아 보여준다.
  Future<void> _findSimilar() async {
    final refImg = await _picker.pickImage(source: ImageSource.gallery);
    if (refImg == null || !mounted) return;
    final added = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => SimilarPhotosScreen(
            project: widget.project, referencePath: refImg.path),
      ),
    );
    if (added != null && added > 0 && mounted) {
      Navigator.of(context).pop(added); // 채우기 완료 → 닫기.
    }
  }

  Widget _list() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _ItemTile(
        item: _items[i],
        periodLabel: SchedulePeriod.periodLabel(
          widget.project.scheduleType,
          widget.project.scheduleConfig,
          _items[i].date,
        ),
        onEditDate: () => _editDate(_items[i]),
        onRemove: () => setState(() => _items.removeAt(i)),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.periodLabel,
    required this.onEditDate,
    required this.onRemove,
  });

  final _BackfillItem item;
  final String periodLabel;
  final VoidCallback onEditDate;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            File(item.path),
            width: 64,
            height: 64,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 64,
              height: 64,
              color: scheme.surfaceContainerHighest,
              child: Icon(Icons.image_not_supported_outlined,
                  color: scheme.onSurfaceVariant),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(periodLabel,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                '${item.date.year}.${item.date.month.toString().padLeft(2, '0')}.${item.date.day.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        TextButton(onPressed: onEditDate, child: const Text('날짜')),
        IconButton(
          tooltip: '제외',
          icon: const Icon(Icons.close),
          onPressed: onRemove,
        ),
      ],
    );
  }
}

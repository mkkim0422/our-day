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

  Future<void> _pick() async {
    final picked = await _picker.pickMultiImage();
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
          if (_items.isNotEmpty)
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

  /// 진입 화면 — 두 가지 채우기 방식을 동등하게 제시(자동 갤러리 띄우기 없음).
  Widget _empty() {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Text('예전 가족 사진으로\n지난 기간을 채워보세요',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800, height: 1.25)),
        const SizedBox(height: 6),
        Text('어떻게 채울지 골라주세요.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 24),
        // 추천: 한 장 고르면 같은 자세(포즈) 사진을 자동으로 모아준다.
        _ChooserCard(
          icon: Icons.image_search,
          title: '비슷한 포즈 사진 자동으로 찾기',
          subtitle: '기준 사진 한 장만 고르면, 갤러리에서 비슷한 자세(포즈)로\n찍힌 사진을 모아서 보여줘요.',
          badge: '추천',
          highlight: true,
          onTap: _findSimilar,
        ),
        const SizedBox(height: 14),
        _ChooserCard(
          icon: Icons.photo_library_outlined,
          title: '직접 여러 장 고르기',
          subtitle: '갤러리에서 원하는 사진을 직접 선택해 한 번에 채워요.',
          onTap: _pick,
        ),
      ],
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

/// 채우기 방식 선택 카드 — 큰 탭 영역 + 아이콘/제목/설명(+ 추천 배지).
class _ChooserCard extends StatelessWidget {
  const _ChooserCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Material(
      color: highlight ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: highlight
                      ? scheme.primary
                      : scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon,
                    size: 28,
                    color: highlight ? scheme.onPrimary : scheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(title,
                              style: text.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(badge!,
                                style: text.labelSmall?.copyWith(
                                    color: scheme.onPrimary,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: text.bodySmall?.copyWith(
                            color: highlight
                                ? scheme.onPrimaryContainer
                                    .withValues(alpha: 0.8)
                                : scheme.onSurfaceVariant,
                            height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
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

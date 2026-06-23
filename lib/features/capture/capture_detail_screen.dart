import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/age_label.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/providers.dart';
import '../../services/providers.dart';
import '../compare/compare_screen.dart';

/// 사진 상세 — 썸네일 탭 시 **풀사이즈**로 보여준다(명세 ② "썸네일 탭 → 상세").
///
/// 핀치 줌, 한 줄 메모(아이디어3), 공유(⑥), 삭제, 비교·타임랩스(⑤) 진입.
class CaptureDetailScreen extends ConsumerStatefulWidget {
  const CaptureDetailScreen({
    super.key,
    required this.project,
    required this.capture,
  });

  final Project project;
  final Capture capture;

  @override
  ConsumerState<CaptureDetailScreen> createState() =>
      _CaptureDetailScreenState();
}

class _CaptureDetailScreenState extends ConsumerState<CaptureDetailScreen> {
  late String? _note = widget.capture.note;
  Set<String> _taggedIds = {};

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    final ids = await ref
        .read(memberRepositoryProvider)
        .memberIdsForCapture(widget.capture.id);
    if (mounted) setState(() => _taggedIds = ids.toSet());
  }

  Future<void> _toggleMember(String memberId) async {
    final next = Set<String>.from(_taggedIds);
    next.contains(memberId) ? next.remove(memberId) : next.add(memberId);
    setState(() => _taggedIds = next);
    await ref
        .read(memberRepositoryProvider)
        .setMembersForCapture(widget.capture.id, next.toList());
  }

  @override
  Widget build(BuildContext context) {
    final file = File(widget.capture.filePath);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.capture.periodLabel),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: '공유',
            onPressed: _share,
          ),
          PopupMenuButton<String>(
            color: Colors.grey[900],
            onSelected: (v) {
              if (v == 'delete') _confirmDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'delete',
                child: Text('삭제', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: file.existsSync()
                ? InteractiveViewer(
                    maxScale: 5,
                    child: Center(child: Image.file(file)),
                  )
                : const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_outlined,
                            color: Colors.white54, size: 56),
                        SizedBox(height: 12),
                        Text('원본 파일을 찾을 수 없어요',
                            style: TextStyle(color: Colors.white54)),
                      ],
                    ),
                  ),
          ),
          _infoBar(context),
        ],
      ),
    );
  }

  Widget _infoBar(BuildContext context) {
    final hasNote = _note != null && _note!.isNotEmpty;
    final settings = ref.watch(appSettingsProvider).value;
    final height = settings?.captureHeights[widget.capture.id];
    final birthday = settings?.projectBirthdays[widget.project.id];
    final age = birthday != null
        ? AgeLabel.format(birthday, widget.capture.capturedAt)
        : null;
    return Container(
      width: double.infinity,
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            age == null
                ? _formatDate(widget.capture.capturedAt)
                : '${_formatDate(widget.capture.capturedAt)} · $age',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          // 한 줄 메모(아이디어3) — 탭하면 추가/수정.
          InkWell(
            onTap: _editNote,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(hasNote ? Icons.edit_note : Icons.add_comment_outlined,
                      color: Colors.white54, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasNote ? _note! : '그날의 한마디를 남겨보세요',
                      style: TextStyle(
                        color: hasNote ? Colors.white : Colors.white38,
                        fontStyle: hasNote ? FontStyle.normal : FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 키 기록(아이디어8 — 성장 차트 데이터).
          InkWell(
            onTap: _editHeight,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.straighten,
                      color: Colors.white54, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    height != null
                        ? '키 ${height.toStringAsFixed(1)} cm'
                        : '키 기록하기',
                    style: TextStyle(
                      color: height != null ? Colors.white : Colors.white38,
                      fontStyle:
                          height != null ? FontStyle.normal : FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _memberTags(context),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.auto_awesome_motion_outlined),
            label: const Text('비교 · 타임랩스 보기'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CompareScreen(project: widget.project),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editNote() async {
    final controller = TextEditingController(text: _note ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('그날의 한마디'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(hintText: '예: 첫 걸음마 뗀 날'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (result == null) return; // 취소.
    await ref
        .read(captureRepositoryProvider)
        .updateNote(widget.capture.id, result);
    if (mounted) {
      setState(() => _note = result.trim().isEmpty ? null : result.trim());
    }
  }

  /// "함께한 사람" 태그 — 프로젝트 구성원이 있을 때만 표시(아이디어7).
  Widget _memberTags(BuildContext context) {
    final members =
        ref.watch(membersProvider(widget.project.id)).value ?? const [];
    if (members.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('함께한 사람',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final m in members)
                FilterChip(
                  label: Text(m.name),
                  selected: _taggedIds.contains(m.id),
                  onSelected: (_) => _toggleMember(m.id),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editHeight() async {
    final current =
        ref.read(appSettingsProvider).value?.captureHeights[widget.capture.id];
    final controller =
        TextEditingController(text: current?.toString() ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('키 기록 (cm)'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: '예: 92.5', suffixText: 'cm'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final cm = double.tryParse(result.trim());
    await ref
        .read(appSettingsProvider.notifier)
        .setCaptureHeight(widget.capture.id, cm);
  }

  Future<void> _share() async {
    await ref.read(shareServiceProvider).shareFiles(
      [widget.capture.filePath],
      text: '그날 우리 · ${widget.capture.periodLabel}',
    );
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이 사진을 삭제할까요?'),
        content: const Text('타임라인에서 사라지고 되돌릴 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final captureRepo = ref.read(captureRepositoryProvider);
    await ref
        .read(photoStorageProvider)
        .deleteFiles(widget.capture.filePath, widget.capture.thumbPath);
    await captureRepo.delete(widget.capture.id);

    final remaining = await captureRepo.listByProject(widget.project.id);
    await ref
        .read(notificationServiceProvider)
        .scheduleForProject(widget.project, remaining);

    if (mounted) Navigator.of(context).pop();
  }

  String _formatDate(DateTime d) => '${d.year}년 ${d.month}월 ${d.day}일';
}

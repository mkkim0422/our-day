import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/age_label.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/providers.dart';
import '../../services/providers.dart';
import '../compare/compare_screen.dart';
import '../decorate/decorate_screen.dart';
import '../home/home_providers.dart';

/// 사진 상세 — 썸네일 탭 시 진입. **전체 사진**(잘리지 않게 contain) + 아래 정보,
/// 좌우 **스와이프로 다른 기록 넘기기**(PageView). 각 사진마다 메모·키·나이·구성원.
/// 사진을 **한 번 더 탭하면** 정보 없는 전체화면 갤러리([_FullscreenGallery]).
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
  PageController? _controller;
  int _index = 0;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final capturesAsync = ref.watch(capturesProvider(widget.project.id));

    return capturesAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black),
        body: Center(
            child: Text('오류: $e',
                style: const TextStyle(color: Colors.white54))),
      ),
      data: (captures) {
        if (captures.isEmpty) {
          // 마지막 사진까지 삭제됨 → 닫기.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).maybePop();
          });
          return const Scaffold(backgroundColor: Colors.black);
        }

        // 컨트롤러 최초 1회 생성(탭한 사진 위치에서 시작).
        if (_controller == null) {
          final i = captures.indexWhere((c) => c.id == widget.capture.id);
          _index = i < 0 ? 0 : i;
          _controller = PageController(initialPage: _index);
        }
        if (_index >= captures.length) _index = captures.length - 1;
        final current = captures[_index];

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text('${current.periodLabel}  ·  ${_index + 1}/${captures.length}'),
            actions: [
              IconButton(
                icon: const Icon(Icons.ios_share),
                tooltip: '공유',
                onPressed: () => _share(current),
              ),
              PopupMenuButton<String>(
                color: Colors.grey[900],
                onSelected: (v) {
                  if (v == 'delete') _confirmDelete(current, captures.length);
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
          body: PageView.builder(
            controller: _controller,
            itemCount: captures.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => _CapturePage(
              project: widget.project,
              capture: captures[i],
              onOpenFullscreen: () => _openFullscreen(captures, i),
            ),
          ),
        );
      },
    );
  }

  /// 사진을 한 번 더 탭 → 정보 없는 전체화면 갤러리(좌우 스와이프로 넘김).
  Future<void> _openFullscreen(List<Capture> captures, int index) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            _FullscreenGallery(captures: captures, initialIndex: index),
      ),
    );
  }

  Future<void> _share(Capture capture) async {
    await ref.read(shareServiceProvider).shareFiles(
      [capture.filePath],
      text: '그날 우리 · ${capture.periodLabel}',
    );
  }

  Future<void> _confirmDelete(Capture capture, int total) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이 사진을 삭제할까요?'),
        content: const Text('타임라인에서 사라지고 되돌릴 수 없어요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final captureRepo = ref.read(captureRepositoryProvider);
    await ref
        .read(photoStorageProvider)
        .deleteFiles(capture.filePath, capture.thumbPath);
    await captureRepo.delete(capture.id);

    final remaining = await captureRepo.listByProject(widget.project.id);
    final birthday =
        ref.read(appSettingsProvider).value?.projectBirthdays[widget.project.id];
    await ref
        .read(notificationServiceProvider)
        .scheduleForProject(widget.project, remaining, birthday: birthday);
    // 스트림(capturesProvider) 갱신으로 PageView가 자동 반영(빈 목록이면 닫힘).
  }
}

/// 한 장의 상세 페이지(전체 사진 + 정보). PageView의 각 페이지.
class _CapturePage extends ConsumerStatefulWidget {
  const _CapturePage({
    required this.project,
    required this.capture,
    required this.onOpenFullscreen,
  });

  final Project project;
  final Capture capture;
  final VoidCallback onOpenFullscreen;

  @override
  ConsumerState<_CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends ConsumerState<_CapturePage> {
  late String? _note = widget.capture.note;
  Set<String> _taggedIds = {};

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  @override
  void didUpdateWidget(_CapturePage old) {
    super.didUpdateWidget(old);
    if (old.capture.id != widget.capture.id) {
      _note = widget.capture.note;
      _loadTags();
    }
  }

  Future<void> _loadTags() async {
    final ids = await ref
        .read(memberRepositoryProvider)
        .memberIdsForCapture(widget.capture.id);
    if (mounted) setState(() => _taggedIds = ids.toSet());
  }

  bool _showOriginal = false;

  @override
  Widget build(BuildContext context) {
    // 꾸민 사진이 있으면 기록에서 그 버전을 기본으로 보여준다(토글로 원본 보기).
    final decorated = widget.capture.decoratedPath;
    final showDecor = decorated != null && !_showOriginal;
    final file = File(showDecor ? decorated : widget.capture.filePath);
    return Column(
      children: [
        Expanded(
          child: file.existsSync()
              // 한 번 더 탭하면 전체화면 갤러리로.
              ? GestureDetector(
                  onTap: widget.onOpenFullscreen,
                  child: SizedBox.expand(
                    child: Image.file(file,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Center(
                            child: Icon(Icons.broken_image_outlined,
                                size: 48, color: Colors.white54))),
                  ),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  age == null
                      ? _formatDate(widget.capture.capturedAt)
                      : '${_formatDate(widget.capture.capturedAt)} · $age',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
              // 꾸민 사진이 있으면 원본/꾸민 사진 전환.
              if (widget.capture.decoratedPath != null)
                TextButton.icon(
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8)),
                  icon: Icon(_showOriginal ? Icons.auto_awesome : Icons.image,
                      size: 16),
                  label: Text(_showOriginal ? '꾸민 사진' : '원본'),
                  onPressed: () =>
                      setState(() => _showOriginal = !_showOriginal),
                ),
            ],
          ),
          const SizedBox(height: 8),
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
                        fontStyle:
                            hasNote ? FontStyle.normal : FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
          _memberTags(),
          const SizedBox(height: 16),
          // 꾸미기 — 가장 눈에 띄는 1차 액션(하단·풀폭).
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('꾸미기'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DecorateScreen(
                    project: widget.project, capture: widget.capture),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
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

  Widget _memberTags() {
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

  Future<void> _toggleMember(String memberId) async {
    final next = Set<String>.from(_taggedIds);
    next.contains(memberId) ? next.remove(memberId) : next.add(memberId);
    setState(() => _taggedIds = next);
    await ref
        .read(memberRepositoryProvider)
        .setMembersForCapture(widget.capture.id, next.toList());
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
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('저장')),
        ],
      ),
    );
    if (result == null) return;
    await ref
        .read(captureRepositoryProvider)
        .updateNote(widget.capture.id, result);
    if (mounted) {
      setState(() => _note = result.trim().isEmpty ? null : result.trim());
    }
  }

  Future<void> _editHeight() async {
    final current =
        ref.read(appSettingsProvider).value?.captureHeights[widget.capture.id];
    final controller = TextEditingController(text: current?.toString() ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('키 기록 (cm)'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration:
              const InputDecoration(hintText: '예: 92.5', suffixText: 'cm'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('저장')),
        ],
      ),
    );
    if (result == null) return;
    final cm = double.tryParse(result.trim());
    await ref
        .read(appSettingsProvider.notifier)
        .setCaptureHeight(widget.capture.id, cm);
  }

  String _formatDate(DateTime d) => '${d.year}년 ${d.month}월 ${d.day}일';
}

/// 전체화면 갤러리 — 정보/여백 없이 사진만. 좌우 스와이프로 넘기고, 핀치 줌,
/// 아무 곳이나 탭하면 닫힘(일반 갤러리 전체보기와 동일한 감각).
class _FullscreenGallery extends StatefulWidget {
  const _FullscreenGallery({required this.captures, required this.initialIndex});

  final List<Capture> captures;
  final int initialIndex;

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.captures.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) {
              final file = File(widget.captures[i].filePath);
              return GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: file.existsSync()
                    ? InteractiveViewer(
                        minScale: 1,
                        maxScale: 5,
                        child: SizedBox.expand(
                          child: Image.file(file,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const Center(
                                  child: Icon(Icons.broken_image_outlined,
                                      size: 48, color: Colors.white54))),
                        ),
                      )
                    : const Center(
                        child: Icon(Icons.broken_image_outlined,
                            color: Colors.white54, size: 56),
                      ),
              );
            },
          ),
          // 닫기 버튼 + 인덱스(상단 안전영역).
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      '${_index + 1} / ${widget.captures.length}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

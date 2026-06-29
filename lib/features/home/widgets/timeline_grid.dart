import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/db/app_database.dart';

/// 촬영 썸네일 그리드(홈 최근·앨범 전체 공용). 셀 탭 → 상세(명세 ②).
///
/// [onReorder]가 주어지면 사진을 **길게 눌러** 전용 "순서 바꾸기" 화면으로 들어가
/// 드래그로 위치를 바꿀 수 있다. 그 화면 상단의 **저장 버튼은 항상 보이며**(스크롤에
/// 가려지지 않음), 저장하면 새 순서가 그리드·타임랩스·비교 등 모든 곳에 반영된다.
class TimelineGrid extends StatelessWidget {
  const TimelineGrid({
    super.key,
    required this.captures,
    required this.onTapCell,
    this.onReorder,
    this.onAddTap,
    this.crossAxisCount = 3,
  });

  final List<Capture> captures;
  final ValueChanged<Capture> onTapCell;

  /// 새 순서(표시 순서, 앞=최신쪽)를 저장하는 콜백. null이면 읽기 전용.
  final ValueChanged<List<Capture>>? onReorder;

  /// 주어지면 그리드 **맨 끝에 '한 컷 더' 타일**을 붙인다(사진을 다 본 뒤
  /// 자연스럽게 다음 컷을 더하도록 — 별도 버튼을 나열하지 않기 위함).
  final VoidCallback? onAddTap;
  final int crossAxisCount;

  static const double _aspect = 0.78;
  static const double _spacing = 8;

  bool get _reorderable => onReorder != null;

  Future<void> _openReorder(BuildContext context) async {
    final result = await Navigator.of(context).push<List<Capture>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _ReorderScreen(
          captures: captures,
          crossAxisCount: crossAxisCount,
        ),
      ),
    );
    if (result != null) onReorder?.call(result);
  }

  @override
  Widget build(BuildContext context) {
    final hasAdd = onAddTap != null;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: captures.length + (hasAdd ? 1 : 0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: _spacing,
        mainAxisSpacing: _spacing,
        childAspectRatio: _aspect,
      ),
      itemBuilder: (context, i) {
        if (hasAdd && i == captures.length) {
          return _AddTile(onTap: onAddTap!);
        }
        return _TimelineCell(
          capture: captures[i],
          onTap: () => onTapCell(captures[i]),
          onLongPress: _reorderable ? () => _openReorder(context) : null,
        );
      },
    );
  }
}

/// 그리드 끝의 '한 컷 더' 타일 — 사진 셀과 같은 비율로 자연스럽게 이어진다.
class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.35), width: 1.5),
              ),
              child: Icon(Icons.add_a_photo_outlined,
                  color: scheme.primary, size: 28),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '한 컷 더',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// 전용 "순서 바꾸기" 화면 — 상단 저장 버튼이 항상 보이고, 본문은 스크롤된다.
/// 저장하면 새 순서를 [Navigator.pop]으로 돌려주고, 닫으면 변경을 버린다.
class _ReorderScreen extends StatefulWidget {
  const _ReorderScreen({required this.captures, required this.crossAxisCount});

  final List<Capture> captures;
  final int crossAxisCount;

  @override
  State<_ReorderScreen> createState() => _ReorderScreenState();
}

class _ReorderScreenState extends State<_ReorderScreen>
    with SingleTickerProviderStateMixin {
  static const double _aspect = 0.78;
  static const double _spacing = 8;

  late final List<Capture> _order = List.of(widget.captures);
  bool _changed = false;

  late final AnimationController _wiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  void _move(int from, int to) {
    setState(() {
      final item = _order.removeAt(from);
      _order.insert(from < to ? to - 1 : to, item);
      _changed = true;
    });
  }

  Future<void> _close() async {
    if (!_changed) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('변경을 저장하지 않고 나갈까요?'),
        content: const Text('바꾼 순서가 사라져요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('계속 편집')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('나가기')),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _close,
          ),
          title: const Text('순서 바꾸기'),
          actions: [
            // 항상 보이는 저장 — 어디서 들어와도 가려지지 않는다.
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_order),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('저장'),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: scheme.primaryContainer.withValues(alpha: 0.4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.drag_indicator, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '사진을 끌어 원하는 자리에 놓으면 순서가 바뀌어요.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final n = widget.crossAxisCount;
                    final cellW = (c.maxWidth - _spacing * (n - 1)) / n;
                    final cellH = cellW / _aspect;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _order.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: n,
                        crossAxisSpacing: _spacing,
                        mainAxisSpacing: _spacing,
                        childAspectRatio: _aspect,
                      ),
                      itemBuilder: (context, i) =>
                          _editableCell(_order[i], i, Size(cellW, cellH)),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 편집 모드 셀 — 흔들리며, 끌어서 다른 셀 위에 놓으면 그 자리로 이동.
  Widget _editableCell(Capture capture, int index, Size cellSize) {
    final cell = _TimelineCell(capture: capture, onTap: () {});
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => d.data != index,
      onAcceptWithDetails: (d) => _move(d.data, index),
      builder: (context, candidate, rejected) {
        final highlight = candidate.isNotEmpty;
        return Draggable<int>(
          data: index,
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedback: _DragFeedback(capture: capture, size: cellSize),
          childWhenDragging: Opacity(opacity: 0.25, child: cell),
          child: AnimatedBuilder(
            animation: _wiggle,
            builder: (context, child) {
              final phase = index.isEven ? 1.0 : -1.0;
              final angle =
                  math.sin(_wiggle.value * 2 * math.pi) * 0.018 * phase;
              return Transform.rotate(angle: angle, child: child);
            },
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: highlight
                    ? Border.all(
                        color: Theme.of(context).colorScheme.primary, width: 2)
                    : null,
              ),
              child: cell,
            ),
          ),
        );
      },
    );
  }
}

/// 끌고 있는 동안 손가락을 따라다니는 셀(살짝 키운 썸네일).
class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.capture, required this.size});
  final Capture capture;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final img = File(capture.decoratedPath ?? capture.thumbPath);
    return Transform.translate(
      offset: Offset(-size.width / 2, -size.height / 2),
      child: Material(
        color: Colors.transparent,
        elevation: 8,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: size.width,
          height: size.width, // 사진 영역만(라벨 제외) 정도로 충분.
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: img.existsSync()
                ? Image.file(img, fit: BoxFit.cover)
                : const ColoredBox(color: Colors.black12),
          ),
        ),
      ),
    );
  }
}

class _TimelineCell extends StatelessWidget {
  const _TimelineCell(
      {required this.capture, required this.onTap, this.onLongPress});
  final Capture capture;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 꾸민 사진이 있으면 기록에 그 버전을 보여준다(원본은 타임랩스용으로 보존).
    final decorated = capture.decoratedPath != null;
    final img = File(decorated ? capture.decoratedPath! : capture.thumbPath);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  img.existsSync()
                      ? Image.file(img, fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                                color: scheme.surfaceContainerHighest,
                                child: Icon(Icons.image_not_supported_outlined,
                                    color: scheme.onSurfaceVariant),
                              ))
                      : Container(
                          color: scheme.surfaceContainerHighest,
                          child: Icon(Icons.image_not_supported_outlined,
                              color: scheme.onSurfaceVariant),
                        ),
                  if (decorated)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.auto_awesome,
                            size: 12, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            capture.periodLabel,
            style: Theme.of(context).textTheme.labelSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

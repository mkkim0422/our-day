import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/db/app_database.dart';

/// 촬영 썸네일 그리드(홈 최근·앨범 전체 공용). 셀 탭 → 상세(명세 ②).
///
/// [onReorder]가 주어지면 사진을 **길게 눌러 "정렬 모드"**로 들어가 드래그로 위치를
/// 바꿀 수 있다(아이폰/갤럭시 홈 화면처럼 흔들리며 재배치). 완료를 누르면 새 순서가
/// 저장돼 그리드·타임랩스·비교 등 모든 곳에 반영된다.
class TimelineGrid extends StatefulWidget {
  const TimelineGrid({
    super.key,
    required this.captures,
    required this.onTapCell,
    this.onReorder,
    this.crossAxisCount = 3,
  });

  final List<Capture> captures;
  final ValueChanged<Capture> onTapCell;

  /// 새 순서(표시 순서, 앞=최신쪽)를 저장하는 콜백. null이면 읽기 전용.
  final ValueChanged<List<Capture>>? onReorder;
  final int crossAxisCount;

  @override
  State<TimelineGrid> createState() => _TimelineGridState();
}

class _TimelineGridState extends State<TimelineGrid>
    with SingleTickerProviderStateMixin {
  static const double _aspect = 0.78;
  static const double _spacing = 8;

  bool _editing = false;
  late List<Capture> _order = List.of(widget.captures);

  late final AnimationController _wiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..repeat(reverse: true);

  bool get _reorderable => widget.onReorder != null;

  @override
  void didUpdateWidget(TimelineGrid old) {
    super.didUpdateWidget(old);
    // 편집 중이 아니면 외부(스트림) 순서를 따라간다.
    if (!_editing) _order = List.of(widget.captures);
  }

  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  void _enterEdit() {
    if (!_reorderable) return;
    setState(() {
      _order = List.of(widget.captures);
      _editing = true;
    });
  }

  void _finishEdit() {
    setState(() => _editing = false);
    widget.onReorder?.call(List.of(_order));
  }

  void _move(int from, int to) {
    setState(() {
      final item = _order.removeAt(from);
      _order.insert(from < to ? to - 1 : to, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cells = _editing ? _order : widget.captures;
    final grid = LayoutBuilder(
      builder: (context, c) {
        final n = widget.crossAxisCount;
        final cellW = (c.maxWidth - _spacing * (n - 1)) / n;
        final cellH = cellW / _aspect;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cells.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: n,
            crossAxisSpacing: _spacing,
            mainAxisSpacing: _spacing,
            childAspectRatio: _aspect,
          ),
          itemBuilder: (context, i) => _editing
              ? _editableCell(cells[i], i, Size(cellW, cellH))
              : _TimelineCell(
                  capture: cells[i],
                  onTap: () => widget.onTapCell(cells[i]),
                  onLongPress: _reorderable ? _enterEdit : null,
                ),
        );
      },
    );

    if (!_editing) return grid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _editBanner(context),
        const SizedBox(height: 10),
        grid,
      ],
    );
  }

  Widget _editBanner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.drag_indicator, size: 18, color: scheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text('사진을 끌어 순서를 바꿔요',
                style: Theme.of(context).textTheme.bodySmall),
          ),
          FilledButton(
            onPressed: _finishEdit,
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('완료'),
          ),
        ],
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

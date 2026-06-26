import 'dart:io';

import 'package:flutter/material.dart';

import '../../../data/db/app_database.dart';

/// 촬영 썸네일 그리드(홈 최근·앨범 전체 공용). 셀 탭 → 상세(명세 ②).
class TimelineGrid extends StatelessWidget {
  const TimelineGrid({
    super.key,
    required this.captures,
    required this.onTapCell,
    this.crossAxisCount = 3,
  });

  final List<Capture> captures;
  final ValueChanged<Capture> onTapCell;
  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: captures.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, i) => _TimelineCell(
        capture: captures[i],
        onTap: () => onTapCell(captures[i]),
      ),
    );
  }
}

class _TimelineCell extends StatelessWidget {
  const _TimelineCell({required this.capture, required this.onTap});
  final Capture capture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 꾸민 사진이 있으면 기록에 그 버전을 보여준다(원본은 타임랩스용으로 보존).
    final decorated = capture.decoratedPath != null;
    final img = File(decorated ? capture.decoratedPath! : capture.thumbPath);
    return InkWell(
      onTap: onTap,
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

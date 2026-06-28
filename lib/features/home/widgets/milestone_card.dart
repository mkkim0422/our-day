import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/utils/milestone.dart';
import '../../../data/db/app_database.dart';

/// 백일·돌 등 마일스톤 자동 카드 (아이디어10).
///
/// 생일이 설정된 프로젝트에서 도달한 마일스톤 근처의 사진을 찾아, 그 시점을
/// 축하하며 "그동안의 변화"(타임랩스·비교)로 이어주는 입구를 홈 상단에 띄운다.
class MilestoneCard extends StatelessWidget {
  const MilestoneCard({
    super.key,
    required this.milestone,
    required this.capture,
    required this.onTap,
  });

  final Milestone milestone;
  final Capture capture;
  final VoidCallback onTap;

  /// 표시할 마일스톤 1건과 그 근처(±[tolDays]) 사진을 고른다. 없으면 null(카드 미표시).
  ///
  /// 도달한 마일스톤 중 가장 최근 것부터, 해당 날짜에 가장 가까운 사진을 찾는다.
  static MilestonePick? pick(
    DateTime birth,
    List<Capture> captures,
    DateTime now, {
    int tolDays = 31,
  }) {
    final reached = Milestones.reached(birth, now);
    for (final m in reached.reversed) {
      Capture? best;
      int? bestDiff;
      for (final c in captures) {
        final diff = c.capturedAt.difference(m.date).inDays.abs();
        if (diff <= tolDays && (bestDiff == null || diff < bestDiff)) {
          best = c;
          bestDiff = diff;
        }
      }
      if (best != null) return MilestonePick(milestone: m, capture: best);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(18);
    final thumb = File(capture.thumbPath);

    return Material(
      color: scheme.primaryContainer.withValues(alpha: 0.55),
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: thumb.existsSync()
                      ? Image.file(thumb, fit: BoxFit.cover)
                      : Container(
                          color: scheme.surface,
                          child: Icon(Icons.cake_outlined,
                              color: scheme.onSurfaceVariant),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${milestone.emoji} ${milestone.label}',
                        style: text.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('그동안의 변화를 타임랩스로 만나보세요',
                        style: text.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.play_circle_fill_rounded,
                  size: 30, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// [MilestoneCard.pick] 결과(마일스톤 + 근처 사진).
class MilestonePick {
  const MilestonePick({required this.milestone, required this.capture});
  final Milestone milestone;
  final Capture capture;
}

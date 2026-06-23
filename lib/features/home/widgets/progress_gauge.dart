import 'package:flutter/material.dart';

import '../../../core/constants/enums.dart';
import '../../../core/utils/schedule_period.dart';
import '../../../data/db/app_database.dart';

/// 진척 게이지 (6장 4번 — 리텐션 핵심).
///
/// "끊김에 관대한 설계"(6장 5번)에 따라 streak가 아니라 **누적 컷 수**를 강조하고,
/// 월간 프로젝트는 올해 12칸을 채우는 진행을 보조로 보여준다.
class ProgressGauge extends StatelessWidget {
  const ProgressGauge({
    super.key,
    required this.project,
    required this.captures,
    required this.now,
  });

  final Project project;
  final List<Capture> captures;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // 회색빛 대신 브랜드 톤의 따뜻한 연한 배경.
        color: scheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${captures.length}',
                  style: text.headlineMedium
                      ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700)),
              const SizedBox(width: 4),
              Text('컷 누적', style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
              const Spacer(),
              if (captures.length >= 4)
                Text('타임랩스 준비됨', style: text.labelMedium?.copyWith(color: scheme.primary)),
            ],
          ),
          if (project.scheduleType == ScheduleType.monthly) ...[
            const SizedBox(height: 14),
            Builder(builder: (_) {
              final filled = _filledMonthsThisYear(); // 한 번만 계산.
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MonthlyDots(filled: filled, scheme: scheme),
                  const SizedBox(height: 6),
                  Text('올해 ${filled.length}/12개월 기록',
                      style: text.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }

  /// 올해 촬영이 있는 월(1~12) 집합.
  Set<int> _filledMonthsThisYear() {
    return captures
        .where((c) => c.capturedAt.year == now.year)
        .map((c) => c.capturedAt.month)
        .toSet();
  }
}

class _MonthlyDots extends StatelessWidget {
  const _MonthlyDots({required this.filled, required this.scheme});
  final Set<int> filled;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(12, (i) {
        final month = i + 1;
        final isFilled = filled.contains(month);
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? scheme.primary : Colors.transparent,
            border: Border.all(
              color: isFilled ? scheme.primary : scheme.outlineVariant,
              width: 1.5,
            ),
          ),
        );
      }),
    );
  }
}

/// 이번 기간에 이미 촬영했는지 — 홈 CTA 상태 판정(6장).
bool hasCaptureInCurrentPeriod(
  Project project,
  List<Capture> captures,
  DateTime now,
) {
  final targetKey = SchedulePeriod.periodKey(
    project.scheduleType,
    project.scheduleConfig,
    now,
  );
  return captures.any((c) =>
      SchedulePeriod.periodKey(
        project.scheduleType,
        project.scheduleConfig,
        c.capturedAt,
      ) ==
      targetKey);
}

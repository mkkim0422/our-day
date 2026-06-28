import 'package:flutter/material.dart';

import '../../../core/utils/schedule_period.dart';
import '../../../data/db/app_database.dart';

/// 진척 게이지 (6장 4번 — 리텐션 핵심).
///
/// "끊김에 관대한 설계"(6장 5번)에 따라 **누적 컷 수**를 가장 크게 보여주고,
/// 보조로 ① 최근 기간 채움 스트립(찍은 기간/빈 기간)과 ② 연속 기록 스트릭을
/// 응원형으로 곁들인다(스트릭이 끊겨도 벌하지 않음 — 2회 이상일 때만 칭찬).
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

  static const _windowSize = 12; // 최근 N개 기간 표시.

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    // 최근 N개 기간(최신→과거)과 각 기간의 촬영 여부.
    final anchors = SchedulePeriod.recentPeriodAnchors(
        project.scheduleType, project.scheduleConfig, now, _windowSize);
    final doneKeys = captures
        .map((c) => SchedulePeriod.periodKey(
            project.scheduleType, project.scheduleConfig, c.capturedAt))
        .toSet();
    // 최신→과거 순의 채움 여부.
    final filled = anchors
        .map((a) => doneKeys.contains(SchedulePeriod.periodKey(
            project.scheduleType, project.scheduleConfig, a)))
        .toList(growable: false);
    final filledCount = filled.where((f) => f).length;
    final streak = _currentStreak(filled);
    final unit = SchedulePeriod.periodUnitLabel(project.scheduleType);

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
              if (captures.isEmpty)
                Text('첫 기록을 기다려요',
                    style: text.titleMedium?.copyWith(
                        color: scheme.primary, fontWeight: FontWeight.w700))
              else ...[
                Text('${captures.length}',
                    style: text.headlineMedium?.copyWith(
                        color: scheme.primary, fontWeight: FontWeight.w700)),
                const SizedBox(width: 2),
                Text('번째 기록',
                    style: text.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
              const Spacer(),
              // 응원형 스트릭(2회 이상일 때만) → 끊겨도 벌하지 않는다.
              if (streak >= 2)
                _StreakChip(streak: streak, scheme: scheme, text: text)
              else if (captures.length >= 4)
                Text('타임랩스 준비됨',
                    style: text.labelMedium?.copyWith(color: scheme.primary)),
            ],
          ),
          // 규칙적 주기(일·주·격주·월·년)에는 최근 기간 스트립을 보여준다.
          if (anchors.isNotEmpty) ...[
            const SizedBox(height: 14),
            _PeriodDots(filled: filled, scheme: scheme),
            const SizedBox(height: 6),
            Text('최근 ${anchors.length}$unit 중 $filledCount$unit 기록',
                style:
                    text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }

  /// 가장 최근 기록 기간부터 과거로 이어지는 연속 기록 수.
  ///
  /// 관대함: 이번 기간(맨 앞)을 아직 안 찍었어도 스트릭이 끊긴 것으로 보지 않고,
  /// 직전 기간부터 연속을 센다.
  int _currentStreak(List<bool> filledNewestFirst) {
    if (filledNewestFirst.isEmpty) return 0;
    var start = 0;
    if (!filledNewestFirst[0]) start = 1; // 이번 기간 미촬영은 봐준다.
    var streak = 0;
    for (var i = start; i < filledNewestFirst.length; i++) {
      if (filledNewestFirst[i]) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }
}

/// 🔥 연속 N회 칩(응원형).
class _StreakChip extends StatelessWidget {
  const _StreakChip(
      {required this.streak, required this.scheme, required this.text});
  final int streak;
  final ColorScheme scheme;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('🔥 연속 $streak회',
          style: text.labelMedium
              ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700)),
    );
  }
}

/// 최근 기간들의 채움 점(최신이 오른쪽). 찍은 기간은 채워진 원, 빈 기간은 테두리.
class _PeriodDots extends StatelessWidget {
  const _PeriodDots({required this.filled, required this.scheme});
  final List<bool> filled; // 최신→과거
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    // 화면엔 과거→최신(왼→오른쪽)으로 보여준다.
    final ordered = filled.reversed.toList(growable: false);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final isFilled in ordered)
          Container(
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
          ),
      ],
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

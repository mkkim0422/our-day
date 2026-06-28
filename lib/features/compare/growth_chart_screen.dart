import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../services/providers.dart';
import '../home/home_providers.dart';

/// 아이디어8 — 성장 차트. 사진별 키(cm) 기록을 시간순 꺾은선으로 시각화.
/// (값은 사진 상세에서 입력. 외부 차트 패키지 없이 CustomPainter로 그린다.)
class GrowthChartScreen extends ConsumerStatefulWidget {
  const GrowthChartScreen({super.key, required this.project});

  final Project project;

  @override
  ConsumerState<GrowthChartScreen> createState() => _GrowthChartScreenState();
}

class _GrowthChartScreenState extends ConsumerState<GrowthChartScreen> {
  final _chartKey = GlobalKey();
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final capturesAsync = ref.watch(capturesProvider(widget.project.id));
    final heights =
        ref.watch(appSettingsProvider).value?.captureHeights ?? const {};

    return Scaffold(
      appBar: AppBar(title: const Text('성장 차트 · 키')),
      body: capturesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오기 오류: $e')),
        data: (captures) {
          // 시간순 + 키가 기록된 컷만.
          final points = captures.reversed
              .where((c) => heights.containsKey(c.id))
              .map((c) => _Point(c.capturedAt, heights[c.id]!, c.periodLabel))
              .toList(growable: false);

          if (points.length < 2) {
            return _empty(context);
          }
          final scheme = Theme.of(context).colorScheme;
          return Column(
            children: [
              Expanded(
                child: RepaintBoundary(
                  key: _chartKey,
                  child: Container(
                    color: scheme.surface,
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('${points.first.cm.toStringAsFixed(1)} → '
                            '${points.last.cm.toStringAsFixed(1)} cm',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w800)),
                        Text('${points.length}회 기록 · '
                            '+${(points.last.cm - points.first.cm).toStringAsFixed(1)} cm 자랐어요',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 20),
                        Expanded(
                          child: CustomPaint(
                            painter: _LineChartPainter(
                              points: points,
                              lineColor: scheme.primary,
                              gridColor: scheme.outlineVariant,
                              labelColor: scheme.onSurfaceVariant,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _exporting ? null : _share,
                          icon: _exporting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.ios_share),
                          label: Text(_exporting ? '만드는 중…' : '공유'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _exporting ? null : _saveToGallery,
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('기기에 저장'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _share() async {
    setState(() => _exporting = true);
    try {
      final share = ref.read(shareServiceProvider);
      final path = await share.captureBoundaryToPng(_chartKey, pixelRatio: 3);
      await share.shareFiles([path],
          text: '그날 우리 — ${widget.project.title} 성장 차트');
    } catch (e) {
      _snack('차트 공유 실패: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// 차트를 기기 사진첩에 저장(⑦).
  Future<void> _saveToGallery() async {
    setState(() => _exporting = true);
    try {
      final share = ref.read(shareServiceProvider);
      final path = await share.captureBoundaryToPng(_chartKey, pixelRatio: 3);
      await share.saveToGallery(path);
      _snack('성장 차트를 사진첩에 저장했어요.');
    } catch (e) {
      _snack('차트 저장 실패: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _empty(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('아직 그래프를 그릴 수 없어요',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('사진 상세에서 키(cm)를 2회 이상 기록하면\n성장 곡선이 나타납니다.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _Point {
  _Point(this.date, this.cm, this.label);
  final DateTime date;
  final double cm;
  final String label;
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.points,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
  });

  final List<_Point> points;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 40.0, padR = 12.0, padT = 16.0, padB = 28.0;
    final plot = Rect.fromLTRB(padL, padT, size.width - padR, size.height - padB);

    final minT = points.first.date.millisecondsSinceEpoch.toDouble();
    final maxT = points.last.date.millisecondsSinceEpoch.toDouble();
    var minY = points.map((p) => p.cm).reduce((a, b) => a < b ? a : b);
    var maxY = points.map((p) => p.cm).reduce((a, b) => a > b ? a : b);
    // y축에 여유.
    final pad = (maxY - minY) == 0 ? 5.0 : (maxY - minY) * 0.15;
    minY -= pad;
    maxY += pad;

    double dx(double t) => maxT == minT
        ? plot.center.dx
        : plot.left + (t - minT) / (maxT - minT) * plot.width;
    double dy(double y) =>
        plot.bottom - (y - minY) / (maxY - minY) * plot.height;

    // 그리드 + y 라벨(3줄).
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = plot.top + plot.height * i / 2;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      final value = maxY - (maxY - minY) * i / 2;
      _label(canvas, value.toStringAsFixed(0), Offset(4, y - 6), labelColor);
    }

    // 선 + 채움.
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final o = Offset(dx(points[i].date.millisecondsSinceEpoch.toDouble()),
          dy(points[i].cm));
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(path, linePaint);

    // 점 + 끝값.
    final dot = Paint()..color = lineColor;
    for (var i = 0; i < points.length; i++) {
      final o = Offset(dx(points[i].date.millisecondsSinceEpoch.toDouble()),
          dy(points[i].cm));
      canvas.drawCircle(o, 4, dot);
    }

    // x 라벨(처음/끝 기간).
    _label(canvas, points.first.label, Offset(plot.left, plot.bottom + 6),
        labelColor);
    _label(canvas, points.last.label,
        Offset(plot.right - 60, plot.bottom + 6), labelColor);
  }

  void _label(Canvas canvas, String text, Offset at, Color color) {
    final tp = TextPainter(
      text: TextSpan(
          text: text, style: TextStyle(color: color, fontSize: 11)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_LineChartPainter old) => old.points != points;
}

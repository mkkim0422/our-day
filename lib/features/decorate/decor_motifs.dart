import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 프리미엄 스킨용 **벡터 일러스트 모티프**(이모지 대신 직접 그려 디자인 품질 확보).
/// 각 모티프는 사진 영역 위에 은은하게 얹히는 장식 요소다.
enum Motif {
  arch, // 보호 아치 라인
  leaves, // 올리브 가지(모서리)
  sparkle, // 4각 반짝이
  confetti, // 색종이
  dottedBorder, // 점선 액자
  sunRays, // 코너 햇살
  hearts, // 하트 클러스터
  stars, // 별 흩뿌림
  rainbow, // 무지개 아치(코너)
  washiTape, // 워시 테이프(상단 모서리)
  bunting, // 가랜드(삼각 깃발)
  snow, // 눈송이
  scallop, // 스캘럽 레이스(하단)
  floral, // 꽃 클러스터
  fern, // 고사리/들풀(하단 코너)
  ruleLines, // 매거진 괘선
  ornaments, // 행잉 오너먼트(홀리데이)
}

/// 스킨의 모티프들을 사진 영역 전체에 그린다.
class SkinMotifsPainter extends CustomPainter {
  SkinMotifsPainter({
    required this.motifs,
    required this.accent,
    this.accent2,
  });

  final List<Motif> motifs;
  final Color accent;
  final Color? accent2;

  @override
  void paint(Canvas canvas, Size size) {
    for (final m in motifs) {
      switch (m) {
        case Motif.arch:
          _arch(canvas, size);
        case Motif.leaves:
          _leaves(canvas, size);
        case Motif.sparkle:
          _sparkles(canvas, size);
        case Motif.confetti:
          _confetti(canvas, size);
        case Motif.dottedBorder:
          _dottedBorder(canvas, size);
        case Motif.sunRays:
          _sunRays(canvas, size);
        case Motif.hearts:
          _hearts(canvas, size);
        case Motif.stars:
          _stars(canvas, size);
        case Motif.rainbow:
          _rainbow(canvas, size);
        case Motif.washiTape:
          _washiTape(canvas, size);
        case Motif.bunting:
          _bunting(canvas, size);
        case Motif.snow:
          _snow(canvas, size);
        case Motif.scallop:
          _scallop(canvas, size);
        case Motif.floral:
          _floral(canvas, size);
        case Motif.fern:
          _fern(canvas, size);
        case Motif.ruleLines:
          _ruleLines(canvas, size);
        case Motif.ornaments:
          _ornaments(canvas, size);
      }
    }
  }

  Paint get _stroke => Paint()
    ..color = accent
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1.4, 2.0)
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  Paint _fill(Color c) => Paint()
    ..color = c
    ..isAntiAlias = true;

  void _arch(Canvas canvas, Size s) {
    final inset = s.width * 0.06;
    final r = Rect.fromLTRB(inset, inset, s.width - inset, s.height - inset);
    final path = Path()
      ..moveTo(r.left, r.bottom)
      ..lineTo(r.left, r.top + r.width / 2)
      ..arcToPoint(Offset(r.right, r.top + r.width / 2),
          radius: Radius.circular(r.width / 2))
      ..lineTo(r.right, r.bottom);
    canvas.drawPath(path, _stroke..color = accent.withValues(alpha: 0.9));
  }

  void _leaves(Canvas canvas, Size s) {
    void sprig(Offset start, double dir, double len) {
      final stroke = _stroke
        ..color = accent
        ..strokeWidth = 2;
      final end = start + Offset(len * dir, -len * 0.9);
      canvas.drawLine(start, end, stroke);
      final leaf = _fill(accent.withValues(alpha: 0.9));
      for (var t = 0.25; t <= 1.0; t += 0.22) {
        final p = Offset.lerp(start, end, t)!;
        for (final side in [1.0, -1.0]) {
          canvas.save();
          canvas.translate(p.dx, p.dy);
          canvas.rotate(dir * side * 0.9 - 0.5);
          canvas.drawOval(
              Rect.fromCenter(center: Offset.zero, width: 13, height: 6), leaf);
          canvas.restore();
        }
      }
    }

    sprig(Offset(s.width * 0.10, s.height * 0.92), 1, s.height * 0.16);
    sprig(Offset(s.width * 0.90, s.height * 0.92), -1, s.height * 0.16);
  }

  void _sparkles(Canvas canvas, Size s) {
    void spark(Offset c, double r) {
      final p = _fill(accent2 ?? Colors.white);
      final path = Path();
      for (var i = 0; i < 4; i++) {
        final a = i * math.pi / 2;
        path.moveTo(c.dx, c.dy);
        path.quadraticBezierTo(
            c.dx + math.cos(a) * r * 0.28,
            c.dy + math.sin(a) * r * 0.28,
            c.dx + math.cos(a) * r,
            c.dy + math.sin(a) * r);
        path.quadraticBezierTo(
            c.dx + math.cos(a + math.pi / 2) * r * 0.28,
            c.dy + math.sin(a + math.pi / 2) * r * 0.28,
            c.dx,
            c.dy);
      }
      canvas.drawPath(path, p);
    }

    spark(Offset(s.width * 0.16, s.height * 0.16), 13);
    spark(Offset(s.width * 0.85, s.height * 0.22), 9);
    spark(Offset(s.width * 0.78, s.height * 0.80), 7);
  }

  void _confetti(Canvas canvas, Size s) {
    final colors = [
      accent,
      accent2 ?? accent,
      const Color(0xFFFFD36E),
      const Color(0xFF9FD8CB),
    ];
    final rnd = math.Random(7);
    for (var i = 0; i < 18; i++) {
      final x = rnd.nextDouble() * s.width;
      final y = rnd.nextDouble() * s.height * 0.22;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rnd.nextDouble() * math.pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-3, -1.5, 6, 3), const Radius.circular(1)),
        _fill(colors[i % colors.length]),
      );
      canvas.restore();
    }
  }

  void _dottedBorder(Canvas canvas, Size s) {
    final inset = s.width * 0.045;
    final r = RRect.fromRectAndRadius(
      Rect.fromLTRB(inset, inset, s.width - inset, s.height - inset),
      const Radius.circular(14),
    );
    final dot = _fill(accent.withValues(alpha: 0.9));
    final path = Path()..addRRect(r);
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final pos = metric.getTangentForOffset(d)!.position;
        canvas.drawCircle(pos, 1.8, dot);
        d += 12;
      }
    }
  }

  void _sunRays(Canvas canvas, Size s) {
    final c = Offset(s.width * 0.88, s.height * 0.14);
    final p = _stroke
      ..color = (accent2 ?? accent).withValues(alpha: 0.9)
      ..strokeWidth = 2;
    for (var i = 0; i < 8; i++) {
      final a = math.pi / 2 + i * (math.pi / 7);
      canvas.drawLine(c + Offset(math.cos(a) * 10, math.sin(a) * 10),
          c + Offset(math.cos(a) * 22, math.sin(a) * 22), p);
    }
    canvas.drawCircle(c, 8, _fill(accent2 ?? accent));
  }

  void _hearts(Canvas canvas, Size s) {
    void heart(Offset c, double w, Color col) {
      final path = Path();
      final top = c.dy - w * 0.1;
      path.moveTo(c.dx, c.dy + w * 0.42);
      path.cubicTo(c.dx - w * 0.62, c.dy - w * 0.02, c.dx - w * 0.52,
          top - w * 0.38, c.dx, top + w * 0.02);
      path.cubicTo(c.dx + w * 0.52, top - w * 0.38, c.dx + w * 0.62,
          c.dy - w * 0.02, c.dx, c.dy + w * 0.42);
      canvas.drawPath(path, _fill(col));
    }

    heart(Offset(s.width * 0.84, s.height * 0.82), 22, accent);
    heart(Offset(s.width * 0.92, s.height * 0.72), 14,
        (accent2 ?? accent).withValues(alpha: 0.85));
  }

  void _stars(Canvas canvas, Size s) {
    void star(Offset c, double r, Color col) {
      final path = Path();
      for (var i = 0; i < 5; i++) {
        final a = -math.pi / 2 + i * 2 * math.pi / 5;
        final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        final a2 = a + math.pi / 5;
        final p2 = c + Offset(math.cos(a2) * r * 0.45, math.sin(a2) * r * 0.45);
        path.lineTo(p2.dx, p2.dy);
      }
      path.close();
      canvas.drawPath(path, _fill(col));
    }

    final rnd = math.Random(3);
    for (var i = 0; i < 6; i++) {
      star(
        Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height * 0.3),
        5 + rnd.nextDouble() * 5,
        (i.isEven ? accent : (accent2 ?? accent)).withValues(alpha: 0.9),
      );
    }
  }

  void _rainbow(Canvas canvas, Size s) {
    final c = Offset(s.width * 0.13, s.height * 0.13);
    final colors = [
      const Color(0xFFF4A8B8),
      const Color(0xFFFFD36E),
      const Color(0xFF9FD8CB),
    ];
    for (var i = 0; i < 3; i++) {
      final p = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: 18.0 + i * 6),
        0,
        math.pi / 2,
        false,
        p,
      );
    }
  }

  void _washiTape(Canvas canvas, Size s) {
    void tape(Offset c, double angle, Color col) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(angle);
      final rect = RRect.fromRectAndRadius(
          const Rect.fromLTWH(-34, -11, 68, 22), const Radius.circular(2));
      canvas.drawRRect(rect, _fill(col.withValues(alpha: 0.55)));
      // 무광 줄무늬.
      final stripe = _fill(Colors.white.withValues(alpha: 0.25));
      for (var x = -28.0; x < 30; x += 9) {
        canvas.drawRect(Rect.fromLTWH(x, -11, 3, 22), stripe);
      }
      canvas.restore();
    }

    tape(Offset(s.width * 0.16, s.height * 0.05), -0.18, accent);
    tape(Offset(s.width * 0.84, s.height * 0.05), 0.18, accent2 ?? accent);
  }

  void _bunting(Canvas canvas, Size s) {
    final y = s.height * 0.06;
    final string = _stroke
      ..color = accent.withValues(alpha: 0.8)
      ..strokeWidth = 1.5;
    final path = Path()
      ..moveTo(0, y)
      ..quadraticBezierTo(s.width / 2, y + 14, s.width, y);
    canvas.drawPath(path, string);
    final cols = [
      accent,
      accent2 ?? accent,
      const Color(0xFFFFD36E),
      const Color(0xFF9FD8CB),
    ];
    const n = 7;
    for (var i = 0; i < n; i++) {
      final t = (i + 0.5) / n;
      final x = t * s.width;
      final fy = y + 14 * (1 - (2 * t - 1) * (2 * t - 1));
      final flag = Path()
        ..moveTo(x - 8, fy)
        ..lineTo(x + 8, fy)
        ..lineTo(x, fy + 16)
        ..close();
      canvas.drawPath(flag, _fill(cols[i % cols.length]));
    }
  }

  void _snow(Canvas canvas, Size s) {
    final rnd = math.Random(11);
    for (var i = 0; i < 26; i++) {
      final x = rnd.nextDouble() * s.width;
      final y = rnd.nextDouble() * s.height;
      final r = 1.5 + rnd.nextDouble() * 3;
      canvas.drawCircle(
          Offset(x, y), r, _fill(Colors.white.withValues(alpha: 0.85)));
    }
  }

  void _scallop(Canvas canvas, Size s) {
    final r = s.width * 0.045;
    final p = _fill(accent.withValues(alpha: 0.9));
    final y = s.height - r * 0.2;
    for (var x = r; x < s.width; x += r * 2) {
      canvas.drawCircle(Offset(x, y), r, p);
    }
  }

  void _floral(Canvas canvas, Size s) {
    void flower(Offset c, double r, Color petal, Color core) {
      for (var i = 0; i < 5; i++) {
        final a = i * 2 * math.pi / 5;
        canvas.drawCircle(
            c + Offset(math.cos(a) * r, math.sin(a) * r), r * 0.62, _fill(petal));
      }
      canvas.drawCircle(c, r * 0.55, _fill(core));
    }

    final core = accent2 ?? const Color(0xFFFFD36E);
    flower(Offset(s.width * 0.13, s.height * 0.86), 12, accent, core);
    flower(Offset(s.width * 0.22, s.height * 0.93), 8, accent, core);
    flower(Offset(s.width * 0.88, s.height * 0.12), 10, accent, core);
  }

  void _fern(Canvas canvas, Size s) {
    void stem(Offset base, double dir) {
      final stroke = _stroke
        ..color = accent
        ..strokeWidth = 1.6;
      final tip = base + Offset(dir * s.width * 0.16, -s.height * 0.22);
      final path = Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(
            base.dx + dir * s.width * 0.04, base.dy - s.height * 0.12, tip.dx, tip.dy);
      canvas.drawPath(path, stroke);
      final leaf = _fill(accent.withValues(alpha: 0.85));
      for (var t = 0.2; t <= 1.0; t += 0.16) {
        final p = Offset.lerp(base, tip, t)!;
        for (final side in [1.0, -1.0]) {
          canvas.save();
          canvas.translate(p.dx, p.dy);
          canvas.rotate(dir * side * 0.8 - 1.0);
          canvas.drawOval(
              Rect.fromCenter(center: Offset.zero, width: 11, height: 4.5), leaf);
          canvas.restore();
        }
      }
    }

    stem(Offset(s.width * 0.10, s.height * 0.96), 1);
    stem(Offset(s.width * 0.90, s.height * 0.96), -1);
  }

  void _ruleLines(Canvas canvas, Size s) {
    final p = _stroke
      ..color = accent
      ..strokeWidth = 2;
    canvas.drawLine(Offset(s.width * 0.08, s.height * 0.08),
        Offset(s.width * 0.92, s.height * 0.08), p);
    final thin = _stroke
      ..color = accent.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(s.width * 0.08, s.height * 0.115),
        Offset(s.width * 0.92, s.height * 0.115), thin);
    canvas.drawLine(Offset(s.width * 0.08, s.height * 0.92),
        Offset(s.width * 0.92, s.height * 0.92), p);
  }

  void _ornaments(Canvas canvas, Size s) {
    final y0 = s.height * 0.04;
    final cols = [accent, accent2 ?? accent, const Color(0xFFE9C46A)];
    final xs = [0.22, 0.5, 0.78];
    final drops = [0.16, 0.24, 0.18];
    for (var i = 0; i < xs.length; i++) {
      final x = s.width * xs[i];
      final cy = y0 + s.height * drops[i];
      canvas.drawLine(Offset(x, y0), Offset(x, cy - 8),
          _stroke..color = accent.withValues(alpha: 0.7)..strokeWidth = 1.2);
      canvas.drawCircle(Offset(x, cy), 9, _fill(cols[i % cols.length]));
      canvas.drawCircle(Offset(x, cy - 9), 2.5, _fill(accent));
    }
  }

  @override
  bool shouldRepaint(SkinMotifsPainter old) =>
      old.motifs != motifs || old.accent != accent || old.accent2 != accent2;
}

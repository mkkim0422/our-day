import 'package:flutter/material.dart';

/// 브랜드 로고 마크 — 카메라 + 렌즈 속 하트(가족·온기). 앱 아이콘과 동일한 모티프의
/// 벡터 버전이라 인트로/스플래시에서 또렷하게(해상도 독립) 그릴 수 있다.
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({
    super.key,
    this.size = 120,
    this.bodyColor = const Color(0xFFFFFFFF),
    this.accentColor = const Color(0xFF1B64DA),
  });

  final double size;

  /// 카메라 본체 색(밝은 크림).
  final Color bodyColor;

  /// 렌즈 링·하트 색(어두운 따뜻함).
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LogoPainter(bodyColor: bodyColor, accentColor: accentColor),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({required this.bodyColor, required this.accentColor});

  final Color bodyColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.shortestSide / 100; // 100단위 디자인 → 실제 픽셀.
    final cx = size.width / 2;
    final cy = size.height / 2;

    final body = Paint()..color = bodyColor..isAntiAlias = true;
    final accent = Paint()..color = accentColor..isAntiAlias = true;

    // 본체(둥근 사각형).
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(cx, cy + 3 * u), width: 60 * u, height: 39 * u),
      Radius.circular(8 * u),
    );
    // 뷰파인더 돌출부.
    final hump = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(cx, cy - 18 * u), width: 19 * u, height: 9 * u),
      Radius.circular(3 * u),
    );
    canvas.drawRRect(hump, body);
    canvas.drawRRect(bodyRect, body);

    // 플래시(우상단 점).
    canvas.drawCircle(Offset(cx + 21 * u, cy - 7 * u), 2.6 * u, accent);

    // 렌즈: 어두운 링 → 크림 디스크 → 하트.
    final lensC = Offset(cx, cy + 4 * u);
    canvas.drawCircle(lensC, 15.5 * u, accent);
    canvas.drawCircle(lensC, 12.2 * u, body);
    _drawHeart(canvas, lensC, 12.5 * u, accent);
  }

  void _drawHeart(Canvas canvas, Offset c, double w, Paint paint) {
    final path = Path();
    final top = c.dy - w * 0.10;
    path.moveTo(c.dx, c.dy + w * 0.42);
    path.cubicTo(
      c.dx - w * 0.62, c.dy - w * 0.02, // 좌하 제어
      c.dx - w * 0.52, top - w * 0.38, // 좌상 제어
      c.dx, top + w * 0.02, // 중앙 상단
    );
    path.cubicTo(
      c.dx + w * 0.52, top - w * 0.38, // 우상 제어
      c.dx + w * 0.62, c.dy - w * 0.02, // 우하 제어
      c.dx, c.dy + w * 0.42, // 하단 꼭짓점
    );
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_LogoPainter old) =>
      old.bodyColor != bodyColor || old.accentColor != accentColor;
}

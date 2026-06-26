import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/db/app_database.dart';
import 'decor_motifs.dart';
import 'skin.dart';

/// 스킨을 적용한 사진 카드 — 이 위젯을 RepaintBoundary로 PNG 내보낸다.
class SkinCard extends StatelessWidget {
  const SkinCard({
    super.key,
    required this.skin,
    required this.capture,
    required this.caption,
    this.dateText,
    this.ageText,
    this.heightText,
    this.width = 340,
    this.filterStrength = 1.0,
    this.captionScale = 1.0,
  });

  final Skin skin;
  final Capture capture;
  final String caption;
  final String? dateText;
  final String? ageText;
  final String? heightText;
  final double width;

  /// 필터 적용 세기(0=원본, 1=완전 적용).
  final double filterStrength;

  /// 캡션 글자 크기 배율(작게/보통/크게).
  final double captionScale;

  bool get _isDark => skin.bg.first.computeLuminance() < 0.35;
  Color get _cardColor => _isDark ? skin.bg.first : Colors.white;
  Color get _onCard => _isDark ? const Color(0xFFEDE9DE) : skin.accent;

  @override
  Widget build(BuildContext context) {
    final matPad = width * 0.055;
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: skin.bg.length == 1 ? skin.bg.first : null,
        gradient: skin.bg.length > 1
            ? LinearGradient(
                colors: skin.bg,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight)
            : null,
      ),
      padding: EdgeInsets.all(matPad),
      child: Container(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        padding: EdgeInsets.all(width * 0.035),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _framedPhoto(),
            SizedBox(height: width * 0.04),
            _textBlock(),
            SizedBox(height: width * 0.02),
          ],
        ),
      ),
    );
  }

  Widget _framedPhoto() {
    final file = File(capture.filePath);
    Widget photo = file.existsSync()
        ? Image.file(file, fit: BoxFit.cover)
        : Container(color: const Color(0xFFE3DCD0));
    // 필터 세기: 원본 위에 필터본을 strength 만큼 겹쳐 블렌딩.
    if (skin.colorFilter != null && filterStrength > 0) {
      final filtered =
          ColorFiltered(colorFilter: skin.colorFilter!, child: photo);
      photo = filterStrength >= 0.99
          ? filtered
          : Stack(fit: StackFit.expand, children: [
              photo,
              Opacity(opacity: filterStrength, child: filtered),
            ]);
    }

    // 4:5 비율로 통일(프리미엄 카드 감성).
    final framed = AspectRatio(aspectRatio: 4 / 5, child: photo);

    switch (skin.frame) {
      case SkinFrame.film:
        return _filmStrip(framed);
      case SkinFrame.arch:
        return ClipPath(clipper: _ArchClipper(), child: _withMotifs(framed));
      case SkinFrame.inset:
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: Border.all(color: skin.accent.withValues(alpha: 0.55)),
          ),
          child: _withMotifs(
              ClipRRect(borderRadius: BorderRadius.circular(4), child: framed)),
        );
      case SkinFrame.plain:
      case SkinFrame.polaroid:
        return _withMotifs(
            ClipRRect(borderRadius: BorderRadius.circular(10), child: framed));
    }
  }

  /// 사진 위에 모티프 레이어를 얹는다.
  Widget _withMotifs(Widget child) {
    if (skin.motifs.isEmpty) return child;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: CustomPaint(
            painter: SkinMotifsPainter(
              motifs: skin.motifs,
              accent: skin.accent,
              accent2: skin.accent2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _filmStrip(Widget framed) {
    Widget holes() => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              8,
              (_) => Container(
                width: 14,
                height: 9,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        );
    return Container(
      color: const Color(0xFF2B2B2E),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          holes(),
          ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: _withMotifs(framed)),
          holes(),
        ],
      ),
    );
  }

  Widget _textBlock() {
    final growth = [ageText, heightText].whereType<String>().join('  ·  ');
    return Column(
      children: [
        if (caption.trim().isNotEmpty)
          Text(
            caption.trim(),
            textAlign: TextAlign.center,
            maxLines: 2,
            style: GoogleFonts.getFont(
              skin.font,
              fontSize: width * 0.075 * captionScale,
              color: _onCard,
              height: 1.2,
            ),
          ),
        if (growth.isNotEmpty) ...[
          SizedBox(height: width * 0.015),
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: width * 0.03, vertical: width * 0.012),
            decoration: BoxDecoration(
              color: skin.accent.withValues(alpha: _isDark ? 0.22 : 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              growth,
              style: GoogleFonts.getFont(
                skin.font,
                fontSize: width * 0.05,
                color: _onCard,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (dateText != null) ...[
          SizedBox(height: width * 0.02),
          Text(
            dateText!,
            style: GoogleFonts.getFont(
              skin.font,
              fontSize: width * 0.04,
              color: _onCard.withValues(alpha: 0.7),
              letterSpacing: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

/// 스킨 선택용 미니 썸네일 — **실제 사진**에 배경·필터·모티프를 적용해 보여준다
/// (폰트/텍스트는 생략해 가볍고 빠르게). 추상 스와치보다 즉시 판단 가능.
class SkinThumb extends StatelessWidget {
  const SkinThumb({super.key, required this.skin, required this.capture});

  final Skin skin;
  final Capture capture;

  @override
  Widget build(BuildContext context) {
    final file = File(capture.thumbPath);
    Widget photo = file.existsSync()
        ? Image.file(file, fit: BoxFit.cover, gaplessPlayback: true)
        : const ColoredBox(color: Color(0xFFE3DCD0));
    if (skin.colorFilter != null) {
      photo = ColorFiltered(colorFilter: skin.colorFilter!, child: photo);
    }
    return Container(
      decoration: BoxDecoration(
        color: skin.bg.length == 1 ? skin.bg.first : null,
        gradient: skin.bg.length > 1
            ? LinearGradient(colors: skin.bg)
            : null,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Stack(
          fit: StackFit.expand,
          children: [
            photo,
            if (skin.motifs.isNotEmpty)
              CustomPaint(
                painter: SkinMotifsPainter(
                  motifs: skin.motifs,
                  accent: skin.accent,
                  accent2: skin.accent2,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 아치형 상단 마스크(보호 사진 프레임).
class _ArchClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final r = math.min(size.width / 2, size.height / 2);
    return Path()
      ..moveTo(0, size.height)
      ..lineTo(0, r)
      ..arcToPoint(Offset(size.width, r),
          radius: Radius.circular(r))
      ..lineTo(size.width, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_ArchClipper oldClipper) => false;
}

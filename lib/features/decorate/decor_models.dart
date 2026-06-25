import 'package:flutter/material.dart';

/// 사진 꾸미기 — **다축 레이어 모델**(딥리서치 기반 재설계).
///
/// 한 장의 사진 위에 독립 축을 쌓는다: 프레임 · 배경(매트) · 필터(ColorFilter.matrix)
/// · 필름효과(CustomPainter 오버레이) · 스티커(드래그 레이어) · 글자 · 성장 스탬프.
/// 새 무거운 패키지 없이 순수 위젯/캔버스로 구현(가족·성장 차별 데코 포함).

// ── 프레임 ──
enum FrameStyle {
  none,
  polaroid, // 하단 두꺼운 흰 여백(문구 자리)
  thick, // 사방 두꺼운 흰 테두리
  film, // 필름 스트립(상하 perforation)
  rounded, // 둥근 모서리
  shadow, // 흰 카드 + 그림자
  doubleLine, // 이중 라인 액자
  tape, // 모서리 마스킹 테이프
}

const List<({FrameStyle style, String name})> kFrames = [
  (style: FrameStyle.none, name: '없음'),
  (style: FrameStyle.polaroid, name: '폴라로이드'),
  (style: FrameStyle.thick, name: '화이트'),
  (style: FrameStyle.film, name: '필름'),
  (style: FrameStyle.rounded, name: '라운드'),
  (style: FrameStyle.shadow, name: '카드'),
  (style: FrameStyle.doubleLine, name: '이중선'),
  (style: FrameStyle.tape, name: '테이프'),
];

// ── 배경(매트) ──
@immutable
class DecorBg {
  const DecorBg(this.name, this.colors);
  final String name;
  final List<Color> colors; // 1색=단색, 2색=그라데이션
  bool get isGradient => colors.length > 1;
}

const List<DecorBg> kBackgrounds = [
  DecorBg('화이트', [Color(0xFFFFFFFF)]),
  DecorBg('크림', [Color(0xFFFFF7EE)]),
  DecorBg('블러시', [Color(0xFFFDE7EF)]),
  DecorBg('라일락', [Color(0xFFEDE6FA)]),
  DecorBg('민트', [Color(0xFFE3F4ED)]),
  DecorBg('하늘', [Color(0xFFE6F0FB)]),
  DecorBg('버터', [Color(0xFFFFF6D6)]),
  DecorBg('피치', [Color(0xFFFFEAE0)]),
  DecorBg('그레이', [Color(0xFFEDEFF2)]),
  DecorBg('선셋', [Color(0xFFFFD9C0), Color(0xFFF7B6D2)]),
  DecorBg('드림', [Color(0xFFD6E8FF), Color(0xFFE9D9FF)]),
  DecorBg('포레스트', [Color(0xFFDFF3E3), Color(0xFFCDE9F0)]),
];

// ── 필터(ColorFilter.matrix · 4x5=20) ──
@immutable
class DecorFilter {
  const DecorFilter(this.name, this.matrix);
  final String name;
  final List<double>? matrix; // null = 원본

  ColorFilter? get colorFilter =>
      matrix == null ? null : ColorFilter.matrix(matrix!);
}

const List<DecorFilter> kFilters = [
  DecorFilter('원본', null),
  DecorFilter('흑백', [
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0,
  ]),
  DecorFilter('세피아', [
    0.393, 0.769, 0.189, 0, 0, //
    0.349, 0.686, 0.168, 0, 0, //
    0.272, 0.534, 0.131, 0, 0, //
    0, 0, 0, 1, 0,
  ]),
  DecorFilter('따뜻', [
    1.10, 0, 0, 0, 12, //
    0, 1.04, 0, 0, 6, //
    0, 0, 0.90, 0, 0, //
    0, 0, 0, 1, 0,
  ]),
  DecorFilter('시원', [
    0.90, 0, 0, 0, 0, //
    0, 1.00, 0, 0, 4, //
    0, 0, 1.16, 0, 12, //
    0, 0, 0, 1, 0,
  ]),
  DecorFilter('페이드', [
    0.80, 0, 0, 0, 30, //
    0, 0.80, 0, 0, 30, //
    0, 0, 0.80, 0, 30, //
    0, 0, 0, 1, 0,
  ]),
  DecorFilter('필름', [
    1.06, 0, 0, 0, 10, //
    0.02, 1.00, 0, 0, 8, //
    0, 0, 0.94, 0, 4, //
    0, 0, 0, 1, 0,
  ]),
  DecorFilter('생생', [
    1.25, -0.05, -0.05, 0, 0, //
    -0.05, 1.25, -0.05, 0, 0, //
    -0.05, -0.05, 1.25, 0, 0, //
    0, 0, 0, 1, 0,
  ]),
  DecorFilter('드리미', [
    1.10, 0.05, 0.05, 0, 18, //
    0.05, 1.02, 0.05, 0, 16, //
    0.06, 0.06, 1.04, 0, 20, //
    0, 0, 0, 1, 0,
  ]),
];

// ── 필름 효과(오버레이, 다중 토글) ──
enum FilmFx { lightLeak, grain, dust, vignette }

const List<({FilmFx fx, String name, IconData icon})> kFilmFx = [
  (fx: FilmFx.lightLeak, name: '라이트릭', icon: Icons.flare),
  (fx: FilmFx.grain, name: '그레인', icon: Icons.grain),
  (fx: FilmFx.dust, name: '먼지', icon: Icons.blur_on),
  (fx: FilmFx.vignette, name: '비네트', icon: Icons.vignette),
];

// ── 스티커(드래그 레이어) ──
/// 캔버스에 올린 스티커 1개(이모지). 위치는 캔버스 대비 정규화(0~1).
class StickerItem {
  StickerItem({
    required this.emoji,
    this.dx = 0.5,
    this.dy = 0.5,
    this.scale = 1.0,
    this.rotation = 0.0,
  });

  final String emoji;
  double dx;
  double dy;
  double scale;
  double rotation;
}

/// 스티커 팔레트(이모지 기반 — 폰트 이모지라 무료·고해상도·한글앱 호환).
const List<String> kStickerPalette = [
  '❤️', '💕', '⭐', '✨', '🌟', '🌸', '🌼', '🌈',
  '☁️', '☀️', '🎀', '👑', '🎈', '🎂', '🧸', '🐻',
  '🐰', '🐣', '🍼', '👣', '💛', '💙', '💚', '💜',
  '🥰', '😍', '📸', '🎉', '🏡', '🌙', '🍀', '🦋',
];

// ── 성장 특화 스탬프(우리 앱 차별점) ──
enum GrowthStamp { age, height, monthCount, milestone }

// 온보딩 샘플 사진 생성기 (순수 Dart, `image` 패키지).
//
// 실행: `dart run tool/generate_samples.dart`
// 산출물(assets/sample/): sample_1.png ~ sample_5.png
//
// 콘셉트: 3인 가족(아빠·엄마·아이)이 매번 다른 배경에서 "비슷한 포즈"로 서 있고,
// 프레임이 갈수록 아이가 점점 커진다. 첫 실행 온보딩에서 5장을 타임랩스로 보여주기 위한
// 플랫 일러스트(실사진 아님).
import 'dart:io';

import 'package:image/image.dart';

const int w = 720;
const int h = 960; // 3:4 세로(타임랩스 비율과 동일)

// 인물 팔레트(따뜻한 톤).
final _skin = ColorRgb8(0xF0, 0xC9, 0xA8);
final _hair = ColorRgb8(0x4A, 0x3A, 0x3F);
final _dadShirt = ColorRgb8(0x5B, 0x7D, 0xB1); // 소프트 블루
final _momShirt = ColorRgb8(0xD9, 0x8A, 0xA8); // 로즈
final _kidShirt = ColorRgb8(0xF2, 0xB4, 0x41); // 옐로
final _pants = ColorRgb8(0x6B, 0x5B, 0x73); // 플럼그레이

/// 프레임별 배경 설정.
class _Scene {
  const _Scene(this.sky, this.ground, {this.band, this.accent, this.dots});
  final List<int> sky; // 위→아래 그라데이션 위쪽
  final List<int> ground; // 바닥 띠 색
  final List<int>? band; // 중간 띠(바다 등)
  final List<int>? accent; // 해/창문 등 포인트
  final List<int>? dots; // 흩뿌리는 점(낙엽/눈)
}

final _scenes = <_Scene>[
  // 1) 봄 공원
  _Scene([0xCD, 0xEA, 0xF5], [0xA7, 0xD4, 0x9B], accent: [0xFF, 0xD3, 0x6B]),
  // 2) 여름 바다
  _Scene([0x9F, 0xD4, 0xF0], [0xF0, 0xDD, 0xA8],
      band: [0x5B, 0xA9, 0xD6], accent: [0xFF, 0xD3, 0x6B]),
  // 3) 가을
  _Scene([0xFB, 0xE0, 0xB8], [0xC9, 0x8A, 0x4B], dots: [0xE0, 0x7A, 0x33]),
  // 4) 겨울
  _Scene([0xDC, 0xE6, 0xF0], [0xEE, 0xF4, 0xFA], dots: [0xFF, 0xFF, 0xFF]),
  // 5) 집
  _Scene([0xF6, 0xE7, 0xDD], [0xC9, 0xA2, 0x7A], accent: [0xBF, 0xDA, 0xF0]),
];

void main() {
  final dir = Directory('assets/sample');
  dir.createSync(recursive: true);

  for (var i = 0; i < _scenes.length; i++) {
    final img = _frame(i);
    File('${dir.path}/sample_${i + 1}.png').writeAsBytesSync(encodePng(img));
  }
  stdout.writeln('생성 완료: ${dir.path}/sample_1..5.png');
}

Image _frame(int i) {
  final s = _scenes[i];
  final img = Image(width: w, height: h);

  final groundTop = (h * 0.66).round();

  // 하늘(세로 그라데이션: sky → 살짝 밝게).
  for (var y = 0; y < groundTop; y++) {
    final t = y / groundTop;
    fillRect(img,
        x1: 0,
        y1: y,
        x2: w - 1,
        y2: y,
        color: ColorRgb8(
          _lerp(s.sky[0], 0xFF, t * 0.25),
          _lerp(s.sky[1], 0xFF, t * 0.25),
          _lerp(s.sky[2], 0xFF, t * 0.25),
        ));
  }

  // 중간 띠(바다 등).
  if (s.band != null) {
    fillRect(img,
        x1: 0,
        y1: (h * 0.5).round(),
        x2: w - 1,
        y2: groundTop,
        color: ColorRgb8(s.band![0], s.band![1], s.band![2]));
  }

  // 바닥.
  fillRect(img,
      x1: 0,
      y1: groundTop,
      x2: w - 1,
      y2: h - 1,
      color: ColorRgb8(s.ground[0], s.ground[1], s.ground[2]));

  // 포인트(해/창문).
  if (s.accent != null) {
    if (i == 4) {
      // 집: 벽에 창문.
      fillRect(img,
          x1: (w * 0.62).round(),
          y1: (h * 0.16).round(),
          x2: (w * 0.86).round(),
          y2: (h * 0.40).round(),
          color: ColorRgb8(s.accent![0], s.accent![1], s.accent![2]),
          radius: 10);
    } else {
      // 해.
      fillCircle(img,
          x: (w * 0.80).round(),
          y: (h * 0.16).round(),
          radius: 54,
          color: ColorRgb8(s.accent![0], s.accent![1], s.accent![2]),
          antialias: true);
    }
  }

  // 흩뿌리는 점(낙엽/눈) — 결정적 의사난수(시드 = 위치).
  if (s.dots != null) {
    for (var k = 0; k < 28; k++) {
      final dx = ((k * 97 + i * 13) % w);
      final dy = ((k * 53 + i * 29) % groundTop);
      fillCircle(img,
          x: dx,
          y: dy,
          radius: 5,
          color: ColorRgb8(s.dots![0], s.dots![1], s.dots![2]),
          antialias: true);
    }
  }

  final footY = (h * 0.92).round();
  final dadH = h * 0.62;
  final momH = h * 0.56;
  // 아이는 프레임이 갈수록 큼: 0.30 → 0.52.
  final kidH = h * (0.30 + 0.055 * i);

  // 같은 배치·비슷한 포즈(프레임마다 손드는 쪽만 살짝 변주).
  _person(img, (w * 0.30).round(), footY, dadH, _dadShirt,
      waveRight: i.isEven);
  _person(img, (w * 0.72).round(), footY, momH, _momShirt,
      waveRight: i.isOdd);
  _person(img, (w * 0.51).round(), footY, kidH, _kidShirt,
      waveRight: i.isEven);

  return img;
}

/// 한 사람(머리+몸통+팔다리)을 [cx] 중심, [footY] 발끝, [ph] 키로 그린다.
void _person(Image img, int cx, int footY, double ph, Color shirt,
    {bool waveRight = false}) {
  final headR = (ph * 0.12).round();
  final headCy = (footY - ph).round() + headR;

  final torsoTop = headCy + (headR * 0.85).round();
  final torsoBottom = (footY - ph * 0.40).round();
  final torsoW = (ph * 0.30).round();

  // 다리.
  final legW = (ph * 0.11).round();
  final legGap = (ph * 0.03).round();
  fillRect(img,
      x1: cx - legGap - legW,
      y1: torsoBottom - 6,
      x2: cx - legGap,
      y2: footY,
      color: _pants,
      radius: legW ~/ 2);
  fillRect(img,
      x1: cx + legGap,
      y1: torsoBottom - 6,
      x2: cx + legGap + legW,
      y2: footY,
      color: _pants,
      radius: legW ~/ 2);

  // 팔(몸통 양옆). 한쪽은 위로 들어 인사 포즈.
  final armW = (ph * 0.075).round();
  final armLen = torsoBottom - torsoTop;
  // 왼팔(항상 아래로).
  fillRect(img,
      x1: cx - torsoW ~/ 2 - armW,
      y1: torsoTop + 4,
      x2: cx - torsoW ~/ 2,
      y2: torsoTop + armLen,
      color: shirt,
      radius: armW ~/ 2);
  // 오른팔: waveRight면 위로(어깨~머리 옆), 아니면 아래로.
  if (waveRight) {
    fillRect(img,
        x1: cx + torsoW ~/ 2,
        y1: headCy - headR,
        x2: cx + torsoW ~/ 2 + armW,
        y2: torsoTop + 10,
        color: shirt,
        radius: armW ~/ 2);
    // 손.
    fillCircle(img,
        x: cx + torsoW ~/ 2 + armW ~/ 2,
        y: headCy - headR,
        radius: (armW * 0.6).round(),
        color: _skin,
        antialias: true);
  } else {
    fillRect(img,
        x1: cx + torsoW ~/ 2,
        y1: torsoTop + 4,
        x2: cx + torsoW ~/ 2 + armW,
        y2: torsoTop + armLen,
        color: shirt,
        radius: armW ~/ 2);
  }

  // 몸통.
  fillRect(img,
      x1: cx - torsoW ~/ 2,
      y1: torsoTop,
      x2: cx + torsoW ~/ 2,
      y2: torsoBottom,
      color: shirt,
      radius: (torsoW * 0.32).round());

  // 머리카락(머리보다 약간 큰 원) → 얼굴.
  fillCircle(img,
      x: cx, y: headCy - (headR * 0.25).round(), radius: headR + 4, color: _hair, antialias: true);
  fillCircle(img, x: cx, y: headCy, radius: headR, color: _skin, antialias: true);
}

int _lerp(int a, int b, double t) => (a + (b - a) * t).round();

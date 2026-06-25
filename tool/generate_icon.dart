// 앱 아이콘/스플래시 소스 PNG 생성기 (순수 Dart, `image` 패키지).
//
// 실행: `dart run tool/generate_icon.dart`
// 산출물(assets/icon/):
//   - app_icon.png            : 전체 아이콘(그라데이션 배경 + 카메라+하트 글리프) — iOS/legacy
//   - app_icon_background.png : 적응형 배경(그라데이션)
//   - app_icon_foreground.png : 적응형 전경(글리프, 투명·세이프존 패딩) — 스플래시에도 사용
//
// 디자인: 연핑크→라일락 파스텔 그라데이션 위에 크림색 카메라, 렌즈 안에 하트(가족·온기).
// 슬로건 "매달 한 컷, 그날의 우리"의 정서를 단순·견고한 플랫 형태로.
import 'dart:io';

import 'package:image/image.dart';

const int size = 1024;

// 브랜드 팔레트 — 따뜻한 파스텔(연핑크 → 라일락).
final _cream = ColorRgb8(0xFF, 0xFF, 0xFF); // 카메라 본체(흰색)
final _berry = ColorRgb8(0xB8, 0x51, 0x78); // 렌즈 링·하트(따뜻한 딥 로즈)
final _gradTop = [0xF2, 0xAD, 0xC8]; // 연핑크
final _gradBottom = [0xC4, 0xA2, 0xE0]; // 라일락

void main() {
  final dir = Directory('assets/icon');
  dir.createSync(recursive: true);

  // 전체 아이콘.
  final full = _gradient();
  _drawCamera(full, size / 2, size / 2 + 8, 1.0);
  File('${dir.path}/app_icon.png').writeAsBytesSync(encodePng(full));

  // 적응형 배경(그라데이션만).
  File('${dir.path}/app_icon_background.png')
      .writeAsBytesSync(encodePng(_gradient()));

  // 적응형 전경 + 스플래시(투명 배경, 세이프존 위해 0.82 배율).
  final fg = Image(width: size, height: size, numChannels: 4);
  _drawCamera(fg, size / 2, size / 2, 0.82);
  File('${dir.path}/app_icon_foreground.png').writeAsBytesSync(encodePng(fg));

  stdout.writeln('생성 완료: ${dir.path}/app_icon{,_background,_foreground}.png');
}

/// 세로 그라데이션 배경.
Image _gradient() {
  final img = Image(width: size, height: size);
  for (var y = 0; y < size; y++) {
    final t = y / (size - 1);
    fillRect(
      img,
      x1: 0,
      y1: y,
      x2: size - 1,
      y2: y,
      color: ColorRgb8(
        _lerp(_gradTop[0], _gradBottom[0], t),
        _lerp(_gradTop[1], _gradBottom[1], t),
        _lerp(_gradTop[2], _gradBottom[2], t),
      ),
    );
  }
  return img;
}

/// 카메라(+렌즈 속 하트)를 [cx],[cy] 중심, [s] 배율로 그린다.
void _drawCamera(Image img, double cx, double cy, double s) {
  double sc(num v) => v * s;

  final bodyW = sc(580);
  final bodyH = sc(380);
  final bodyTop = cy - bodyH / 2 + sc(26);
  final bodyLeft = cx - bodyW / 2;

  // 뷰파인더 돌출부(상단 중앙).
  final humpW = sc(180), humpH = sc(78);
  fillRect(
    img,
    x1: (cx - humpW / 2).round(),
    y1: (bodyTop - humpH + sc(14)).round(),
    x2: (cx + humpW / 2).round(),
    y2: (bodyTop + sc(20)).round(),
    color: _cream,
    radius: sc(26),
  );

  // 본체(둥근 사각형).
  fillRect(
    img,
    x1: bodyLeft.round(),
    y1: bodyTop.round(),
    x2: (bodyLeft + bodyW).round(),
    y2: (bodyTop + bodyH).round(),
    color: _cream,
    radius: sc(76),
  );

  // 플래시(본체 우상단 작은 점).
  fillCircle(
    img,
    x: (bodyLeft + bodyW - sc(72)).round(),
    y: (bodyTop + sc(70)).round(),
    radius: sc(26).round(),
    color: _berry,
    antialias: true,
  );

  // 렌즈: 어두운 링 → 크림 디스크 → 하트.
  final lensCx = cx.round();
  final lensCy = (bodyTop + bodyH / 2 + sc(8)).round();
  fillCircle(img, x: lensCx, y: lensCy, radius: sc(150).round(), color: _berry, antialias: true);
  fillCircle(img, x: lensCx, y: lensCy, radius: sc(118).round(), color: _cream, antialias: true);
  _drawHeart(img, cx, lensCy.toDouble(), sc(120), _berry);
}

/// 하트(원 2개 + 아래 삼각형).
void _drawHeart(Image img, double cx, double cy, double w, Color color) {
  final lobeR = (w * 0.27).round();
  final dx = w * 0.24;
  final lobeY = (cy - w * 0.12).round();
  fillCircle(img, x: (cx - dx).round(), y: lobeY, radius: lobeR, color: color, antialias: true);
  fillCircle(img, x: (cx + dx).round(), y: lobeY, radius: lobeR, color: color, antialias: true);
  fillPolygon(
    img,
    vertices: [
      Point(cx - w * 0.49, cy - w * 0.06),
      Point(cx + w * 0.49, cy - w * 0.06),
      Point(cx, cy + w * 0.46),
    ],
    color: color,
  );
}

int _lerp(int a, int b, double t) => (a + (b - a) * t).round();

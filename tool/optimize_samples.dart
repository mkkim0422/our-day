// 샘플 이미지 최적화 — assets/sample/sample_N.png(대용량) → sample_N.jpg(경량).
//
// 실행: `dart run tool/optimize_samples.dart`
// 가로 1280px로 다운스케일 + JPG q88 인코딩 → APK 용량·디코딩 비용 절감.
// 원본 PNG는 처리 후 삭제(전체 백업은 etc/sample_ghibli/에 보관).
import 'dart:io';

import 'package:image/image.dart';

const _targetWidth = 1280;

void main() {
  final dir = Directory('assets/sample');
  for (var i = 1; i <= 5; i++) {
    final png = File('${dir.path}/sample_$i.png');
    if (!png.existsSync()) {
      stdout.writeln('건너뜀: ${png.path} 없음');
      continue;
    }
    final decoded = decodePng(png.readAsBytesSync());
    if (decoded == null) {
      stdout.writeln('디코드 실패: ${png.path}');
      continue;
    }
    final resized = decoded.width > _targetWidth
        ? copyResize(decoded, width: _targetWidth)
        : decoded;
    final jpg = File('${dir.path}/sample_$i.jpg');
    jpg.writeAsBytesSync(encodeJpg(resized, quality: 88));
    png.deleteSync();
    final kb = (jpg.lengthSync() / 1024).round();
    stdout.writeln('sample_$i.jpg  ${resized.width}x${resized.height}  ${kb}KB');
  }
  stdout.writeln('최적화 완료.');
}

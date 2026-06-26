import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 이미지 지각 해시(dHash) — 사진의 "생김새"를 64비트로 요약.
///
/// 같은 장소·같은 포즈 사진 찾기에 쓴다: 두 해시의 [hammingDistance]가 작을수록
/// 시각적으로 비슷하다. 밝기/리사이즈/약한 보정에 강한 gradient 기반(dHash).
class ImageHash {
  const ImageHash._();

  /// 바이트 → 64비트 dHash. 디코딩 실패 시 null.
  static int? ofBytes(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    // 9x8 그레이스케일로 줄여 가로 인접 픽셀의 밝기 증감을 비트로.
    final small = img.copyResize(decoded,
        width: 9, height: 8, interpolation: img.Interpolation.average);
    final gray = img.grayscale(small);
    var hash = 0;
    var bit = 0;
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        final left = gray.getPixel(x, y).r;
        final right = gray.getPixel(x + 1, y).r;
        if (left < right) hash |= (1 << bit);
        bit++;
      }
    }
    return hash;
  }

  /// 두 해시의 다른 비트 수(0=동일, 64=정반대).
  static int hammingDistance(int a, int b) {
    var x = a ^ b;
    var count = 0;
    while (x != 0) {
      count += x & 1;
      x >>= 1;
    }
    return count;
  }

  /// 0~1 유사도(1=동일).
  static double similarity(int a, int b) => 1 - hammingDistance(a, b) / 64.0;
}

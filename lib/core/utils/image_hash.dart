import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 사진의 시각 시그니처 — 구조(dHash) + 컬러 블록.
///
/// 메이저앱의 "후보 생성(recall)" 단계에 해당. dHash 하나만 쓰면 밝기 그래디언트
/// 구도만 보지만, 4x4 평균색을 함께 보면 같은 장소·옷·분위기까지 잡아낸다.
class PhotoSignature {
  const PhotoSignature(this.dhash, this.colorBlocks);

  /// 64비트 구조 해시.
  final int dhash;

  /// 4x4 그리드 평균색(RGB) = 48바이트.
  final Uint8List colorBlocks;
}

/// 이미지 지각 해시(dHash) + 컬러 시그니처 유틸 — 온디바이스, 외부 모델 없음.
///
/// 같은 장소·같은 포즈 사진 찾기에 쓴다: [signatureSimilarity]가 클수록 비슷하다.
class ImageHash {
  const ImageHash._();

  /// 바이트 → 64비트 dHash. 디코딩 실패 시 null.
  static int? ofBytes(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    return _dhashOf(decoded);
  }

  /// 바이트 → 구조+컬러 시그니처. 디코딩 실패 시 null. (한 번만 디코딩)
  static PhotoSignature? signatureOf(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final dhash = _dhashOf(decoded);
    final blocks = img.copyResize(decoded,
        width: 4, height: 4, interpolation: img.Interpolation.average);
    final color = Uint8List(48);
    var k = 0;
    for (var y = 0; y < 4; y++) {
      for (var x = 0; x < 4; x++) {
        final p = blocks.getPixel(x, y);
        color[k++] = p.r.toInt();
        color[k++] = p.g.toInt();
        color[k++] = p.b.toInt();
      }
    }
    return PhotoSignature(dhash, color);
  }

  /// 9x8 그레이스케일로 줄여 가로 인접 픽셀의 밝기 증감을 비트로.
  static int _dhashOf(img.Image src) {
    final small = img.copyResize(src,
        width: 9, height: 8, interpolation: img.Interpolation.average);
    final gray = img.grayscale(small);
    var hash = 0;
    var bit = 0;
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        if (gray.getPixel(x, y).r < gray.getPixel(x + 1, y).r) {
          hash |= (1 << bit);
        }
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

  /// 0~1 구조 유사도(1=동일).
  static double similarity(int a, int b) => 1 - hammingDistance(a, b) / 64.0;

  /// 컬러 시그니처 유사도(0~1) — 16블록 평균 RGB 거리 기반.
  static double colorSimilarity(Uint8List a, Uint8List b) {
    if (a.length != b.length || a.isEmpty) return 0;
    var sum = 0.0;
    for (var i = 0; i < a.length; i += 3) {
      final dr = a[i] - b[i];
      final dg = a[i + 1] - b[i + 1];
      final db = a[i + 2] - b[i + 2];
      sum += math.sqrt(dr * dr + dg * dg + db * db);
    }
    final blocks = a.length / 3;
    const maxDist = 441.6729; // sqrt(255^2 * 3)
    return 1 - (sum / blocks) / maxDist;
  }

  /// 구조 60% + 컬러 40% 결합 유사도(0~1).
  static double signatureSimilarity(PhotoSignature a, PhotoSignature b) {
    final s = similarity(a.dhash, b.dhash);
    final c = colorSimilarity(a.colorBlocks, b.colorBlocks);
    return 0.6 * s + 0.4 * c;
  }
}

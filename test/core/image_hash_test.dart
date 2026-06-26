import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:our_day/core/utils/image_hash.dart';

void main() {
  group('ImageHash', () {
    test('hammingDistance/similarity 기본', () {
      expect(ImageHash.hammingDistance(0, 0), 0);
      expect(ImageHash.hammingDistance(0xF, 0x0), 4);
      expect(ImageHash.similarity(5, 5), 1.0);
    });

    test('비슷한 이미지가 다른 이미지보다 유사도 높음', () {
      // 좌→우 밝기 그라데이션(가로) 두 장은 비슷, 세로 그라데이션은 다름.
      img.Image horizontal({int shift = 0}) {
        final im = img.Image(width: 64, height: 64);
        for (var y = 0; y < 64; y++) {
          for (var x = 0; x < 64; x++) {
            final v = (((x + shift) / 64) * 255).clamp(0, 255).toInt();
            im.setPixelRgb(x, y, v, v, v);
          }
        }
        return im;
      }

      img.Image vertical() {
        final im = img.Image(width: 64, height: 64);
        for (var y = 0; y < 64; y++) {
          for (var x = 0; x < 64; x++) {
            final v = ((y / 64) * 255).toInt();
            im.setPixelRgb(x, y, v, v, v);
          }
        }
        return im;
      }

      final ref = ImageHash.ofBytes(img.encodeJpg(horizontal()))!;
      final similarHash =
          ImageHash.ofBytes(img.encodeJpg(horizontal(shift: 3)))!;
      final differentHash = ImageHash.ofBytes(img.encodeJpg(vertical()))!;

      final simSimilar = ImageHash.similarity(ref, similarHash);
      final simDifferent = ImageHash.similarity(ref, differentHash);

      expect(simSimilar, greaterThan(simDifferent));
      expect(simSimilar, greaterThan(0.8));
    });
  });
}

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:our_day/core/utils/image_hash.dart';

/// 시그니처 계산(signatureOf)이 **정확하고 안전**한지 기기 없이 결정적으로 검증한다.
/// (스캔 hot path는 dart:ui 네이티브 디코더 signatureFromBytes를 쓰지만, 그건 엔진이
/// 필요해 헤드리스 유닛에서 못 돈다 — 같은 시그니처 수학을 쓰는 signatureOf로
/// 알고리즘·손상바이트 안전성의 회귀를 막는다. 네이티브 경로는 실기로 검증.)
Uint8List _jpeg(int seed) {
  final im = img.Image(width: 64, height: 64);
  // seed로 좌우 밝기 그라데이션 + 블록을 다르게 → 구분 가능한 이미지.
  for (var y = 0; y < 64; y++) {
    for (var x = 0; x < 64; x++) {
      final v = ((x + seed * 13) * 4) % 256;
      im.setPixelRgb(x, y, v, (y * 4 + seed * 7) % 256, (seed * 40) % 256);
    }
  }
  return Uint8List.fromList(img.encodeJpg(im, quality: 90));
}

void main() {
  // ★ ANR 근본 원인 회귀 방지: dHash 최상위 비트(bit 63)가 켜지면 int가 음수가 되어
  //   부호있는 >> 산술 시프트는 hammingDistance를 무한 루프에 빠뜨려 UI를 멈춘다.
  //   부호없는 >>> 로 고친 뒤엔 즉시·정확히 끝나야 한다. (옛 코드면 이 테스트는
  //   30초 타임아웃으로 실패한다.)
  group('hammingDistance: 최상위 비트(음수 해시)에서도 멈추지 않음', () {
    test('1<<63 vs 0 → 정확히 1비트 차이', () {
      const top = 1 << 63; // Dart 64비트에선 음수(Int64 최솟값)
      expect(ImageHash.hammingDistance(top, 0), 1);
      expect(ImageHash.hammingDistance(0, top), 1);
    });
    test('음수 해시 vs 양수 해시 유사도가 즉시 계산된다', () {
      const a = 1 << 63; // 음수
      const b = 0x7FFFFFFFFFFFFFFF; // 양수(63비트 전부 1)
      // 64비트 전부 다름 → 거리 64 → 유사도 0.
      expect(ImageHash.hammingDistance(a, b), 64);
      expect(ImageHash.similarity(a, b), 0.0);
    });
    test('모든 비트 1(-1) vs 0 → 64비트 차이', () {
      expect(ImageHash.hammingDistance(-1, 0), 64);
    });
  });

  test('signatureOf: 디코딩 성공 + 시그니처 생성', () {
    expect(ImageHash.signatureOf(_jpeg(1)), isNotNull, reason: '디코딩되어야 함');
    expect(ImageHash.signatureOf(_jpeg(9)), isNotNull);
  });

  test('signatureOf: 자기 자신 유사도 > 다른 이미지 유사도', () {
    final a = ImageHash.signatureOf(_jpeg(1))!;
    final aCopy = ImageHash.signatureOf(_jpeg(1))!; // 동일 내용
    final b = ImageHash.signatureOf(_jpeg(40))!; // 많이 다른 이미지

    final self = ImageHash.signatureSimilarity(a, aCopy);
    final diff = ImageHash.signatureSimilarity(a, b);
    expect(self, greaterThan(diff),
        reason: '같은 이미지가 더 높은 유사도여야 함 (self=$self diff=$diff)');
    expect(self, greaterThan(0.9), reason: '동일 이미지는 매우 높아야 함');
  });

  test('signatureOf: 깨진 바이트는 null(예외 없이)', () {
    // image 패키지 디코더는 손상 데이터에서 예외를 던질 수 있다 — 흡수돼야 한다.
    final bad = Uint8List.fromList([1, 2, 3, 4, 5]);
    expect(ImageHash.signatureOf(bad), isNull);
  });

  test('signaturesFromThumbs: null 입력은 null로 보존(길이 유지)', () async {
    // 네이티브 디코딩 자체는 엔진이 필요하지만, null 처리·길이 보존은 검증 가능.
    final sigs = await ImageHash.signaturesFromThumbs([null, null]);
    expect(sigs.length, 2);
    expect(sigs[0], isNull);
    expect(sigs[1], isNull);
  });
}

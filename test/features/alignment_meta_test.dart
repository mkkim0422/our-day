import 'package:flutter_test/flutter_test.dart';
import 'package:our_day/features/capture/alignment_meta.dart';

void main() {
  test('identity 기본값', () {
    expect(AlignmentMeta.identity.isIdentity, isTrue);
    expect(const AlignmentMeta(dx: 0.1).isIdentity, isFalse);
  });

  test('toMap/fromMap 라운드트립', () {
    const meta = AlignmentMeta(dx: 0.12, dy: -0.05, scale: 1.4, rotation: 0.3);
    final restored = AlignmentMeta.fromMap(meta.toMap());
    expect(restored.dx, closeTo(0.12, 1e-9));
    expect(restored.dy, closeTo(-0.05, 1e-9));
    expect(restored.scale, closeTo(1.4, 1e-9));
    expect(restored.rotation, closeTo(0.3, 1e-9));
  });

  test('fromMap 결측치는 identity로 보정', () {
    final m = AlignmentMeta.fromMap({'dx': 0.2});
    expect(m.dx, 0.2);
    expect(m.scale, 1.0);
    expect(m.rotation, 0.0);
  });
}

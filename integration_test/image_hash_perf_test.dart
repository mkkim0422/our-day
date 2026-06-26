import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:our_day/core/utils/image_hash.dart';

/// 기기에서 실제로 실행되는 통합 테스트 — "비슷한 사진" 스캔의 핵심 hot path
/// (네이티브 디코딩 + 시그니처)가 **멈추지 않고 빠른지** 측정한다.
/// 순수 Dart image 패키지가 특정 입력에서 hang하던 문제를 dart:ui로 교체한 검증.
Future<Uint8List> _makePng(int w, int h, double shift) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  for (var x = 0; x < w; x++) {
    final v = (((x / w) + shift) % 1.0);
    canvas.drawRect(
      Rect.fromLTWH(x.toDouble(), 0, 1, h.toDouble()),
      Paint()
        ..color = Color.fromARGB(
            255, (v * 255).toInt(), 90, (255 - v * 255).toInt()),
    );
  }
  final img = await recorder.endRecording().toImage(w, h);
  final bd = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return bd!.buffer.asUint8List();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('signatureFromBytes: 빠르고 멈추지 않으며 유사/비유사를 구분',
      (tester) async {
    final base = await _makePng(240, 320, 0.0);
    final near = await _makePng(240, 320, 0.02); // 거의 같은 이미지
    final diff = await _makePng(240, 320, 0.5); // 완전히 다른 이미지

    final sBase = await ImageHash.signatureFromBytes(base);
    final sNear = await ImageHash.signatureFromBytes(near);
    final sDiff = await ImageHash.signatureFromBytes(diff);

    expect(sBase, isNotNull, reason: '네이티브 디코딩이 동작해야 함');
    expect(sNear, isNotNull);
    expect(sDiff, isNotNull);

    final simNear = ImageHash.signatureSimilarity(sBase!, sNear!);
    final simDiff = ImageHash.signatureSimilarity(sBase, sDiff!);
    debugPrint('PERF sim near=$simNear diff=$simDiff');
    expect(simNear, greaterThan(simDiff),
        reason: '거의 같은 이미지가 더 높은 유사도여야 함');

    // 처리량: 300장을 디코딩+시그니처 — 절대 hang하면 안 됨.
    final sw = Stopwatch()..start();
    for (var i = 0; i < 300; i++) {
      final s = await ImageHash.signatureFromBytes(base);
      expect(s, isNotNull);
    }
    sw.stop();
    debugPrint('PERF: 300x signatureFromBytes = ${sw.elapsedMilliseconds}ms '
        '(${(sw.elapsedMilliseconds / 300).toStringAsFixed(2)}ms/장)');
    // 기기에서 수 초 내여야 한다(예전엔 무한 hang). 넉넉히 15초 상한.
    expect(sw.elapsedMilliseconds, lessThan(15000),
        reason: '300장이 15초 안에 끝나야 함(멈추면 안 됨)');
  });
}

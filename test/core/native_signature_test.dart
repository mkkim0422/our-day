import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:our_day/core/utils/image_hash.dart';

/// 비슷한 사진 스캔의 핵심 hot path(dart:ui 네이티브 디코딩 + 시그니처)가
/// **멈추지 않고 빠르며 유사/비유사를 구분하는지** 검증.
/// 순수 Dart image 패키지가 hang하던 문제를 dart:ui로 바꾼 뒤의 회귀 방지.
Future<Uint8List> _png(int w, int h, double shift) async {
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
  TestWidgetsFlutterBinding.ensureInitialized();

  test('signatureFromBytes: 유사/비유사 구분', () async {
    final base = await _png(240, 320, 0.0);
    final near = await _png(240, 320, 0.02);
    final diff = await _png(240, 320, 0.5);

    final sBase = await ImageHash.signatureFromBytes(base);
    final sNear = await ImageHash.signatureFromBytes(near);
    final sDiff = await ImageHash.signatureFromBytes(diff);
    expect(sBase, isNotNull);
    expect(sNear, isNotNull);
    expect(sDiff, isNotNull);

    final simNear = ImageHash.signatureSimilarity(sBase!, sNear!);
    final simDiff = ImageHash.signatureSimilarity(sBase, sDiff!);
    expect(simNear, greaterThan(simDiff));
    expect(simNear, greaterThan(0.85));
  });

  test('signatureFromBytes: 300장이 멈추지 않고 빠르게 끝난다', () async {
    final base = await _png(240, 320, 0.0);
    final sw = Stopwatch()..start();
    for (var i = 0; i < 300; i++) {
      final s = await ImageHash.signatureFromBytes(base);
      expect(s, isNotNull);
    }
    sw.stop();
    // ignore: avoid_print
    print('PERF: 300x signatureFromBytes = ${sw.elapsedMilliseconds}ms '
        '(${(sw.elapsedMilliseconds / 300).toStringAsFixed(2)}ms/장)');
    expect(sw.elapsedMilliseconds, lessThan(15000));
  });

  test('손상 바이트는 null(크래시 없음)', () async {
    final s = await ImageHash.signatureFromBytes(
        Uint8List.fromList([1, 2, 3, 4, 5]));
    expect(s, isNull);
  });
}

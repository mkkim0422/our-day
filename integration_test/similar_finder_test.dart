import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:our_day/services/gallery/similar_photo_finder.dart';

/// 기기에서 실제로 실행되는 통합 테스트 — 갤러리(시드 사진)에 대해
/// survey()→findSimilar()가 **멈추지 않고** 측정·예측·검색·취소까지 마치는지 검증.
/// 실행 전 갤러리에 이미지가 있어야 하며 사진 권한이 허용돼 있어야 한다.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('survey + findSimilar: 멈춤 없이 측정·예측·검색·취소', (tester) async {
    // 테스트 환경에선 권한 다이얼로그를 띄울 수 없으므로 검사 우회.
    // OS 레벨 READ_MEDIA_IMAGES는 설치 시 -g로 부여한다.
    PhotoManager.setIgnorePermissionCheck(true);
    const finder = SimilarPhotoFinder();

    final access = await finder.requestAccess();
    debugPrint('TESTLOG access=$access');

    // ── survey: 총 장수 + 장당 속도 실측 → 예측 ──
    final sw0 = Stopwatch()..start();
    final survey = await finder.survey();
    sw0.stop();
    debugPrint('TESTLOG survey total=${survey.total} '
        'ms/photo=${survey.msPerPhoto.toStringAsFixed(1)} '
        'quick=${survey.quickCount} took=${sw0.elapsedMilliseconds}ms '
        'quickEst=${survey.quickEstimate.inSeconds}s '
        'fullEst=${survey.fullEstimate.inSeconds}s');
    expect(survey.hasPhotos, isTrue, reason: '시드 사진이 보여야 함');
    expect(survey.total, greaterThanOrEqualTo(40));
    expect(survey.msPerPhoto, greaterThan(0));
    expect(sw0.elapsedMilliseconds, lessThan(20000), reason: 'survey가 빨라야 함');

    // 기준 사진: 갤러리 첫 장의 원본 바이트(자기 자신과 높은 유사도가 나와야 함).
    final paths = await PhotoManager.getAssetPathList(
        type: RequestType.image, onlyAll: true);
    final assets = await paths.first.getAssetListRange(start: 0, end: 1);
    final refBytes = await assets.first.originBytes;
    expect(refBytes, isNotNull, reason: '기준 사진 바이트를 읽어야 함');

    // ── findSimilar: 진행률·카운트·부분결과 콜백 수집, 멈춤 없이 완료 ──
    var lastProgress = 0.0;
    var scannedSeen = 0;
    var partialSeen = false;
    final sw = Stopwatch()..start();
    final matches = await finder.findSimilar(
      refBytes!,
      scanLimit: survey.quickCount,
      budget: const Duration(seconds: 45),
      onProgress: (p) => lastProgress = p,
      onScanned: (s, t) => scannedSeen = s,
      onPartial: (m) => partialSeen = true,
    );
    sw.stop();
    debugPrint('TESTLOG findSimilar matches=${matches.length} '
        'progress=${lastProgress.toStringAsFixed(2)} scanned=$scannedSeen '
        'partial=$partialSeen took=${sw.elapsedMilliseconds}ms '
        'top=${matches.isEmpty ? "-" : matches.first.similarity.toStringAsFixed(2)}');
    expect(sw.elapsedMilliseconds, lessThan(70000), reason: '절대 hang하면 안 됨');
    expect(scannedSeen, greaterThan(0), reason: 'recall이 사진을 훑어야 함');
    expect(partialSeen, isTrue, reason: '부분결과가 즉시 전달돼야 함');
    expect(lastProgress, greaterThan(0.9), reason: '완료까지 진행돼야 함');
    expect(matches, isNotEmpty, reason: '기준 사진 자신 등 비슷 사진이 나와야 함');
    expect(matches.first.similarity, greaterThan(0.5),
        reason: '자기 자신과의 유사도는 높아야 함');

    // ── 취소: 즉시 멈추고 빠르게 반환(무한 스피너 불가) ──
    var checks = 0;
    final swc = Stopwatch()..start();
    final cancelled = await finder.findSimilar(
      refBytes,
      scanLimit: survey.quickCount,
      isCancelled: () {
        checks++;
        return checks > 1; // 첫 배치 후 취소
      },
    );
    swc.stop();
    debugPrint('TESTLOG cancel -> ${cancelled.length} matches '
        'in ${swc.elapsedMilliseconds}ms');
    expect(swc.elapsedMilliseconds, lessThan(25000), reason: '취소는 빨라야 함');
  });
}

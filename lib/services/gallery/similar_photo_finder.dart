import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/utils/image_hash.dart';

/// 사진 접근 권한 상태(전체/일부/거부).
enum GalleryAccess { full, limited, denied }

/// 갤러리에서 기준 사진과 비슷한 후보 1건.
class SimilarMatch {
  const SimilarMatch(this.asset, this.similarity);
  final AssetEntity asset;
  final double similarity; // 0~1
}

/// 검색 전 미리보기 — 총 사진 수 + 이 기기에서 실측한 장당 처리시간으로,
/// "빠른 검색 / 전체 검색"이 각각 몇 초/분 걸릴지 **예측**해 사용자에게 보여준다.
/// (사용자는 자기 사진이 몇 장인지 모르고 알 필요도 없다 — 앱이 재고 알려준다.)
class GallerySurvey {
  const GallerySurvey({
    required this.total,
    required this.msPerPhoto,
    required this.quickCount,
  });

  /// 갤러리 총 사진 수.
  final int total;

  /// 이 기기에서 장당 처리시간(ms) — 표본을 실제로 돌려 측정.
  final double msPerPhoto;

  /// '빠른 검색'이 훑을 장수(전 기간 분산 표본).
  final int quickCount;

  bool get hasPhotos => total > 0;

  /// '전체 검색'이 훑을 장수(상한 적용).
  int get fullCount => math.min(total, 6000);

  /// 포즈 재랭킹 등 고정 오버헤드(초). 표본 외 일정 비용.
  static const double _fixedSec = 12;

  Duration estimate(int count) {
    final sec = _fixedSec + (msPerPhoto * count) / 1000.0;
    return Duration(milliseconds: (sec * 1000).round());
  }

  Duration get quickEstimate => estimate(quickCount);
  Duration get fullEstimate => estimate(fullCount);
}

/// 후보 1건의 시각 점수(1단계 recall 결과).
class _Scored {
  _Scored(this.asset, this.visual);
  final AssetEntity asset;
  final double visual;
}

/// 비교할 "뼈"(연결된 두 관절). 위치·크기에 무관하게 **방향(각도)** 만 본다.
const _bones = <List<PoseLandmarkType>>[
  [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
  [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
  [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
  [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
  [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
  [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
  [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
  [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
  [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
  [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
  [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
  [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
];

/// 갤러리를 뒤져 기준 사진과 **비슷한 자세(포즈)** 로 찍힌 사진을 찾는다.
///
/// 이 앱은 "같은 포즈로 주기적으로 찍는" 가족사진 앱이다. 그래서 핵심 신호는
/// 인물 동일성이 아니라 **자세** — Google ML Kit **포즈 추정**으로 관절 키포인트를
/// 뽑아, 연결된 관절의 **방향 벡터(뼈 각도)** 로 정규화해 비교한다. 위치·크기·
/// 화면 내 인물 크기에 무관하게 "자세가 얼마나 닮았는지"만 본다.
///
///  - 기준 사진에서 **포즈가 잡히면**: 후보에 포즈 검출을 돌려 자세 유사도(60%) +
///    시각 유사도(40%)로 재랭킹. 포즈를 못 잡은 후보는 탈락이 아니라 데모트해
///    "거의 똑같은 사진"이 항상 노출되게 한다.
///  - 포즈가 없으면: 시각 시그니처(dHash 구조 + 컬러 블록)로만 정렬.
class SimilarPhotoFinder {
  const SimilarPhotoFinder();

  Future<bool> ensurePermission() async {
    final ps = await PhotoManager.requestPermissionExtend();
    return ps.isAuth || ps.hasAccess;
  }

  /// 사진 접근 권한을 요청하고 결과를 전체/일부/거부로 알린다.
  /// "일부만 허용"이면 그 사진들만 보이므로 검색 품질이 떨어진다 → 호출부에서 안내.
  Future<GalleryAccess> requestAccess() async {
    final ps = await PhotoManager.requestPermissionExtend();
    if (ps == PermissionState.authorized) return GalleryAccess.full;
    if (ps.hasAccess) return GalleryAccess.limited;
    return GalleryAccess.denied;
  }

  /// 검색 전 갤러리를 빠르게 조사: 총 장수 + 장당 처리시간(실측) → 예측치 산출.
  /// 화면은 이걸로 "사진 N장 · 빠른검색 약 X초 / 전체검색 약 Y분"을 보여준다.
  Future<GallerySurvey> survey() async {
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    ).timeout(const Duration(seconds: 10), onTimeout: () => <AssetPathEntity>[]);
    if (paths.isEmpty) {
      return const GallerySurvey(total: 0, msPerPhoto: 30, quickCount: 0);
    }
    final all = paths.first;
    final total = await all.assetCountAsync
        .timeout(const Duration(seconds: 8), onTimeout: () => 0);
    if (total == 0) {
      return const GallerySurvey(total: 0, msPerPhoto: 30, quickCount: 0);
    }
    // 표본 32장을 전 기간에서 골라 recall과 같은 작업(썸네일+시그니처)을 재본다.
    final sample = await _collectSpread(all, total, math.min(total, 32));
    final ms = await _probeMsPerPhoto(sample);
    debugPrint('[similar] survey total=$total ms/photo=${ms.toStringAsFixed(1)}');
    return GallerySurvey(
        total: total, msPerPhoto: ms, quickCount: math.min(total, 1500));
  }

  /// 표본을 recall과 동일하게 16장씩 동시 처리해 장당 ms를 실측. 표본 없으면 폴백.
  Future<double> _probeMsPerPhoto(List<AssetEntity> sample) async {
    if (sample.isEmpty) return 30;
    final sw = Stopwatch()..start();
    const batch = 16;
    var n = 0;
    for (var start = 0; start < sample.length; start += batch) {
      final end = math.min(start + batch, sample.length);
      final sub = sample.sublist(start, end);
      final thumbs = await Future.wait(sub.map((a) => _safeThumb(a, 100)));
      await Future.wait(thumbs.map((t) => t == null
          ? Future<PhotoSignature?>.value(null)
          : ImageHash.signatureFromBytes(t)
              .timeout(const Duration(seconds: 3), onTimeout: () => null)
              .catchError((_) => null)));
      n += sub.length;
    }
    sw.stop();
    if (n == 0) return 30;
    // 실측에 여유(20%)를 더해 과소예측 방지(콜드 캐시 등).
    return (sw.elapsedMilliseconds / n) * 1.2;
  }

  /// [want]장을 전 기간([total])에 **균등 분산**해 가져온다. 최신 N장만 보면 과거
  /// 사진에 닿지 못해 "연도별"이 깨지므로. 부분만 처리돼도 전 연도가 섞이도록
  /// 버킷을 라운드로빈으로 인터리브한다.
  Future<List<AssetEntity>> _collectSpread(
      AssetPathEntity all, int total, int want) async {
    if (want <= 0) return const [];
    if (total <= want) {
      return await all.getAssetListRange(start: 0, end: total).timeout(
          const Duration(seconds: 12),
          onTimeout: () => <AssetEntity>[]);
    }
    const buckets = 12;
    final perBucket = (want / buckets).ceil();
    final parts = <List<AssetEntity>>[];
    for (var b = 0; b < buckets; b++) {
      final start = (total * b / buckets).floor();
      final end = math.min(start + perBucket, total);
      if (start >= end) continue;
      try {
        final part = await all.getAssetListRange(start: start, end: end).timeout(
            const Duration(seconds: 8),
            onTimeout: () => <AssetEntity>[]);
        if (part.isNotEmpty) parts.add(part);
      } catch (_) {}
    }
    // 라운드로빈 인터리브 → 앞부분만 처리돼도 전 연도가 섞이게.
    final out = <AssetEntity>[];
    var added = true;
    for (var i = 0; added; i++) {
      added = false;
      for (final part in parts) {
        if (i < part.length) {
          out.add(part[i]);
          added = true;
        }
      }
    }
    return out;
  }

  /// 기준 사진 바이트 [refBytes]와 비슷한 자세의 사진을 유사도 높은 순으로.
  ///
  /// [onProgress]는 0~1. 포즈 모드일 땐 0~0.45 recall + 0.45~1 포즈 분석.
  Future<List<SimilarMatch>> findSimilar(
    Uint8List refBytes, {
    // 실유저는 사진이 수만 장. getAssetListRange(0, N)로 **최근 N장만** 가져와
    // 총 장수와 무관하게 시간·메모리를 N에 묶는다(전체를 훑지 않음). 1단계 recall은
    // 가벼우니 폭넓게 보고(연도별 타임랩스는 과거 사진까지 닿아야 하므로), 무거운
    // 포즈 ML은 상위 후보 소수만 돌린다.
    int scanLimit = 1500,
    int posePool = 30,
    int topN = 60,
    double minVisual = 0.5, // 포즈 없을 때 시각 하한
    // 안전 상한(무한 멈춤 방지). 평소엔 isCancelled/scanLimit가 먼저 끝낸다.
    Duration budget = const Duration(minutes: 20),
    // 사용자가 '중지'를 누르면 true → 다음 단계에서 즉시 멈추고 최선결과 반환.
    bool Function()? isCancelled,
    void Function(double progress)? onProgress,
    // 스캔한 장수/계획 장수 — "1,200 / 1,500장 · 약 30초 남음" 표시용.
    void Function(int scanned, int planned)? onScanned,
    // 1단계 결과가 나오는 즉시 화면에 흘려보낸다(점진 표시) → 전 과정이 끝날 때까지
    // 빈 스피너로 기다리지 않게. 구글포토식 "결과 먼저, 정렬은 계속 정교화".
    void Function(List<SimilarMatch> partial)? onPartial,
  }) async {
    final clock = Stopwatch()..start();
    bool stop() => clock.elapsed >= budget || (isCancelled?.call() ?? false);

    final detector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.single),
    );
    try {
      onProgress?.call(0.01); // 즉시 움직임(0%에 갇힌 것처럼 안 보이게).
      final tmpDir = await getTemporaryDirectory();

      // 갤러리 앨범 목록 — 네이티브 호출이라 타임아웃으로 감싼다.
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      ).timeout(const Duration(seconds: 10),
          onTimeout: () => <AssetPathEntity>[]);
      if (paths.isEmpty) return const [];
      final all = paths.first;

      // ★ 총 장수·범위 조회도 만장 갤러리에선 느릴 수 있어 타임아웃 필수.
      //   (여기 멈춤이 "사진이 너무 많아서" 프리징되던 가장 유력한 지점이었다.)
      final total = await all.assetCountAsync
          .timeout(const Duration(seconds: 8), onTimeout: () => 0);
      if (total == 0) return const [];
      // 최신 N장이 아니라 **전 기간에 분산**해 가져온다(연도별 커버리지).
      final assets = await _collectSpread(all, total, math.min(total, scanLimit));
      if (assets.isEmpty) return const [];
      debugPrint('[similar] scan ${assets.length} of $total');

      final refSig = await ImageHash.signatureFromBytes(refBytes);
      if (refSig == null) return const []; // 기준 사진 디코딩 실패.

      // ── 1단계 recall: dart:ui 네이티브 디코딩 시그니처(빠름). 진행률 0.01→0.45 ──
      // 모든 단계에 타임아웃 → 클라우드 전용/손상 등 한 장이 막혀도 전체가 안 멈춤.
      final scored = <_Scored>[];
      const batch = 16;
      for (var start = 0; start < assets.length; start += batch) {
        if (stop()) break; // 중지/예산초과 시 지금까지로 마무리.
        final end = math.min(start + batch, assets.length);
        final sub = assets.sublist(start, end);
        final thumbs = await Future.wait(sub.map((a) => _safeThumb(a, 100)));
        final sigs = await Future.wait(thumbs.map((t) => t == null
            ? Future<PhotoSignature?>.value(null)
            : ImageHash.signatureFromBytes(t)
                .timeout(const Duration(seconds: 3), onTimeout: () => null)
                .catchError((_) => null)));
        for (var k = 0; k < sub.length; k++) {
          final s = sigs[k];
          if (s != null) {
            scored.add(
                _Scored(sub[k], ImageHash.signatureSimilarity(refSig, s)));
          }
        }
        onProgress?.call(0.01 + 0.44 * end / assets.length);
        onScanned?.call(end, assets.length);
        // UI 스레드가 스피너·진행률을 그릴 틈을 준다(메인 스레드 포화/ANR 방지).
        await Future<void>.delayed(Duration.zero);
      }
      debugPrint('[similar] recall done: ${scored.length} scored '
          'in ${clock.elapsedMilliseconds}ms');
      if (scored.isEmpty) return const [];
      scored.sort((a, b) => b.visual.compareTo(a.visual));

      // 1단계 결과를 **즉시** 화면에 흘려보낸다 — 사용자는 바로 사진을 본다.
      List<SimilarMatch> recallView() => scored
          .where((s) => s.visual >= minVisual)
          .take(topN)
          .map((s) => SimilarMatch(s.asset, s.visual))
          .toList();
      onPartial?.call(recallView());

      // ── 기준 포즈 검출 ──
      final refPose =
          stop() ? null : await _detectPose(detector, refBytes, tmpDir);
      final poseMode = refPose != null && refPose.length >= 3;
      debugPrint('[similar] refPose=${refPose?.length} poseMode=$poseMode');

      // 포즈가 없는 기준(또는 예산 초과): 시각 유사도로만.
      if (!poseMode) {
        onProgress?.call(1);
        return recallView();
      }

      // ── 2단계: 상위 후보만 포즈 재랭킹(0.45→1). 예산 초과 시 중단하고,
      //    포즈를 못 돌린 후보는 recall 점수로 살려 결과 누락 0. ──
      final pool = scored.take(posePool).toList();
      final matches = <SimilarMatch>[];
      final processed = <String>{};
      for (var i = 0; i < pool.length; i++) {
        if (stop()) break;
        final v = pool[i].visual;
        double score;
        final bytes = await _safeThumb(pool[i].asset, 512);
        final cand =
            bytes == null ? null : await _detectPose(detector, bytes, tmpDir);
        if (cand != null && cand.length >= 3) {
          final poseSim = _poseSimilarity(refPose, cand);
          score = (0.55 * poseSim + 0.45 * v).clamp(0.0, 1.0);
        } else {
          score = 0.6 * v;
        }
        matches.add(SimilarMatch(pool[i].asset, score));
        processed.add(pool[i].asset.id);
        onProgress?.call(0.45 + 0.55 * (i + 1) / pool.length);
        await Future<void>.delayed(Duration.zero);
      }

      // 포즈를 못 돌린(예산 초과/풀 밖) 후보도 recall 점수로 합류 — 누락 방지.
      for (final s in scored) {
        if (processed.contains(s.asset.id) || s.visual < minVisual) continue;
        matches.add(SimilarMatch(s.asset, 0.6 * s.visual));
      }

      matches
        ..removeWhere((m) => m.similarity < 0.35)
        ..sort((a, b) => b.similarity.compareTo(a.similarity));
      onProgress?.call(1);
      final result = matches.length > topN ? matches.sublist(0, topN) : matches;
      onPartial?.call(result);
      debugPrint('[similar] done: ${matches.length} matches');
      return result;
    } finally {
      await detector.close();
    }
  }

  /// 썸네일을 안전하게 가져온다 — 타임아웃 + 예외를 모두 null로 흡수.
  /// 만장 갤러리엔 클라우드 전용/접근불가 사진이 섞여 throw하므로, 이를 감싸지
  /// 않으면 Future.wait 전체가 실패해 스캔이 멈춘다(1% 고정의 원인).
  Future<Uint8List?> _safeThumb(AssetEntity a, int longSide) async {
    try {
      return await a
          .thumbnailDataWithSize(_fitSize(a, longSide))
          .timeout(const Duration(seconds: 4), onTimeout: () => null);
    } catch (_) {
      return null;
    }
  }

  /// 원본 종횡비를 보존한 썸네일 크기(긴 변 [longSide]). dHash 비교 시 기준 사진
  /// (전체 비율)과 후보가 **같은 구도**가 되도록 — 정사각 크롭이면 같은 사진도
  /// 어긋난다. dims를 모르면 정사각으로 폴백.
  ThumbnailSize _fitSize(AssetEntity a, int longSide) {
    final w = a.orientatedWidth;
    final h = a.orientatedHeight;
    if (w <= 0 || h <= 0) return ThumbnailSize.square(longSide);
    if (w >= h) {
      final th = (longSide * h / w).round().clamp(1, longSide);
      return ThumbnailSize(longSide, th);
    }
    final tw = (longSide * w / h).round().clamp(1, longSide);
    return ThumbnailSize(tw, longSide);
  }

  /// 바이트 → 뼈 방향 단위벡터 맵(뼈이름 → [ux, uy]). 사람/포즈 없으면 빈 맵,
  /// 실패 시 null. 신뢰도 0.5 미만 관절은 제외.
  Future<Map<String, List<double>>?> _detectPose(
      PoseDetector detector, Uint8List bytes, Directory tmpDir) async {
    File? tmp;
    try {
      tmp = File(p.join(tmpDir.path, 'mlkit_pose_scan.jpg'));
      await tmp.writeAsBytes(bytes, flush: true);
      // 타임아웃 — ML Kit 포즈 검출이 막혀도 전체 스캔이 멈추지 않게.
      final poses = await detector
          .processImage(InputImage.fromFilePath(tmp.path))
          .timeout(const Duration(seconds: 8), onTimeout: () => const <Pose>[]);
      if (poses.isEmpty) return <String, List<double>>{};

      final lm = poses.first.landmarks;
      final bones = <String, List<double>>{};
      for (final bone in _bones) {
        final a = lm[bone[0]];
        final b = lm[bone[1]];
        if (a == null || b == null) continue;
        if (a.likelihood < 0.5 || b.likelihood < 0.5) continue;
        final dx = b.x - a.x;
        final dy = b.y - a.y;
        final len = math.sqrt(dx * dx + dy * dy);
        if (len < 1e-3) continue;
        bones['${bone[0].name}_${bone[1].name}'] = [dx / len, dy / len];
      }
      return bones;
    } catch (_) {
      return null;
    } finally {
      try {
        await tmp?.delete();
      } catch (_) {}
    }
  }

  /// 두 자세의 유사도(0~1) — 공통 뼈들의 방향 코사인 평균. 공통 뼈가 3개 미만이면 0.
  double _poseSimilarity(
      Map<String, List<double>> a, Map<String, List<double>> b) {
    var sum = 0.0;
    var n = 0;
    for (final key in a.keys) {
      final vb = b[key];
      if (vb == null) continue;
      final va = a[key]!;
      final cos = (va[0] * vb[0] + va[1] * vb[1]).clamp(-1.0, 1.0);
      sum += (cos + 1) / 2; // [-1,1] → [0,1]
      n++;
    }
    if (n < 3) return 0;
    return (sum / n).clamp(0.0, 1.0);
  }
}

final similarPhotoFinderProvider =
    Provider<SimilarPhotoFinder>((ref) => const SimilarPhotoFinder());

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

  /// 기준 사진 바이트 [refBytes]와 비슷한 자세의 사진을 유사도 높은 순으로.
  ///
  /// [onProgress]는 0~1. 포즈 모드일 땐 0~0.4 recall + 0.4~1 포즈 분석.
  Future<List<SimilarMatch>> findSimilar(
    Uint8List refBytes, {
    // 실유저는 사진이 수만 장. getAssetListRange(0, N)로 **최근 N장만** 가져와
    // 총 장수와 무관하게 시간·메모리를 N에 묶는다(전체를 훑지 않음).
    // 네이티브 디코딩이 장당 ~1.3ms라 500장도 1초 미만. 포즈 검출(ML)이 시간을
    // 지배하므로 상위 45장만 재랭킹한다.
    int scanLimit = 500,
    int posePool = 45,
    int topN = 60,
    double minVisual = 0.5, // 포즈 없을 때 시각 하한
    void Function(double progress)? onProgress,
  }) async {
    final detector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.single),
    );
    try {
      onProgress?.call(0.01); // 즉시 움직임(0%에 갇힌 것처럼 안 보이게).
      final tmpDir = await getTemporaryDirectory();

      // 갤러리 최근 N장(메타데이터만 — 총 장수 수만이어도 빠름).
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      ).timeout(const Duration(seconds: 10),
          onTimeout: () => <AssetPathEntity>[]);
      if (paths.isEmpty) return const [];
      final all = paths.first;
      final total = await all.assetCountAsync;
      final count = math.min(total, scanLimit);
      if (count == 0) return const [];
      final assets = await all.getAssetListRange(start: 0, end: count);
      debugPrint('[similar] scan ${assets.length} of $total');

      final refSig = await ImageHash.signatureFromBytes(refBytes);
      if (refSig == null) return const []; // 기준 사진 디코딩 실패.

      // ── 1단계 recall: dart:ui 네이티브 디코딩 시그니처(빠름). 진행률 0.01→0.5 ──
      // 모든 단계에 타임아웃 → 클라우드 전용/손상 등 한 장이 막혀도 전체가 안 멈춤.
      // (recall을 먼저 돌려 진행률이 0%에서 바로 움직이고, 느린 ML 포즈는 50% 이후로.)
      final scored = <_Scored>[];
      const batch = 16;
      for (var start = 0; start < assets.length; start += batch) {
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
        onProgress?.call(0.01 + 0.49 * end / assets.length);
      }
      debugPrint('[similar] recall done: ${scored.length} scored');
      if (scored.isEmpty) return const [];
      scored.sort((a, b) => b.visual.compareTo(a.visual));

      // ── 기준 포즈 검출(타임아웃). 0%가 아니라 ~50% 지점에서 수행 ──
      final refPose = await _detectPose(detector, refBytes, tmpDir);
      final poseMode = refPose != null && refPose.length >= 3;
      debugPrint('[similar] refPose=${refPose?.length} poseMode=$poseMode');

      // 포즈가 없는 기준: 시각 유사도로만.
      if (!poseMode) {
        onProgress?.call(1);
        return scored
            .where((s) => s.visual >= minVisual)
            .take(topN)
            .map((s) => SimilarMatch(s.asset, s.visual))
            .toList();
      }

      // ── 2단계: 포즈 재랭킹. 진행률 0.5→1 ──
      // 포즈를 못 잡은 후보도 탈락이 아니라 데모트(거의 똑같은 사진을 살림).
      final pool = scored.take(posePool).toList();
      final matches = <SimilarMatch>[];
      for (var i = 0; i < pool.length; i++) {
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
        onProgress?.call(0.5 + 0.5 * (i + 1) / pool.length);
      }
      matches
        ..removeWhere((m) => m.similarity < 0.35)
        ..sort((a, b) => b.similarity.compareTo(a.similarity));
      onProgress?.call(1);
      debugPrint('[similar] done: ${matches.length} matches');
      return matches.length > topN ? matches.sublist(0, topN) : matches;
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

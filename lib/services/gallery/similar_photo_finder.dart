import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/utils/image_hash.dart';

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
///  - 기준 사진에서 **포즈가 잡히면**: 후보를 포즈 검출로 걸러 사람 자세가 있는
///    사진만 남기고, 자세 유사도(80%) + 시각 유사도(20%)로 재랭킹.
///  - 포즈가 없으면: 시각 시그니처(dHash 구조 + 컬러 블록)로만 정렬.
class SimilarPhotoFinder {
  const SimilarPhotoFinder();

  Future<bool> ensurePermission() async {
    final ps = await PhotoManager.requestPermissionExtend();
    return ps.isAuth || ps.hasAccess;
  }

  /// 기준 사진 바이트 [refBytes]와 비슷한 자세의 사진을 유사도 높은 순으로.
  ///
  /// [onProgress]는 0~1. 포즈 모드일 땐 0~0.4 recall + 0.4~1 포즈 분석.
  Future<List<SimilarMatch>> findSimilar(
    Uint8List refBytes, {
    int scanLimit = 600,
    int posePool = 150, // 포즈 모드에서 포즈 검출할 시각 상위 후보 수
    int topN = 60,
    double minVisual = 0.5, // 포즈 없을 때 시각 하한
    double minPose = 0.5, // 포즈 모드에서 자세 유사도 하한
    void Function(double progress)? onProgress,
  }) async {
    final refSig = ImageHash.signatureOf(refBytes);
    if (refSig == null) return const [];

    final detector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.single),
    );
    try {
      // 기준 사진 포즈 검출 → 모드 결정.
      final refPose = await _detectPose(detector, refBytes);
      final poseMode = refPose != null && refPose.length >= 3;

      // 갤러리 최근 N장.
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );
      if (paths.isEmpty) return const [];
      final all = paths.first;
      final total = await all.assetCountAsync;
      final count = math.min(total, scanLimit);
      if (count == 0) return const [];
      final assets = await all.getAssetListRange(start: 0, end: count);

      // ── 1단계 recall: 시각 시그니처(빠르게 후보 추리기) ──
      final recallSpan = poseMode ? 0.4 : 1.0;
      final scored = <_Scored>[];
      for (var i = 0; i < assets.length; i++) {
        final Uint8List? thumb =
            await assets[i].thumbnailDataWithSize(const ThumbnailSize(96, 96));
        if (thumb != null) {
          final sig = ImageHash.signatureOf(thumb);
          if (sig != null) {
            scored.add(
                _Scored(assets[i], ImageHash.signatureSimilarity(refSig, sig)));
          }
        }
        if (i % 8 == 0) onProgress?.call(recallSpan * (i + 1) / assets.length);
      }
      scored.sort((a, b) => b.visual.compareTo(a.visual));

      // 포즈가 없는 기준: 시각 유사도로만.
      if (!poseMode) {
        onProgress?.call(1);
        return scored
            .where((s) => s.visual >= minVisual)
            .take(topN)
            .map((s) => SimilarMatch(s.asset, s.visual))
            .toList();
      }

      // ── 2단계: 포즈 검출 + 자세 유사도 재랭킹 ──
      final pool = scored.take(posePool).toList();
      final matches = <SimilarMatch>[];
      for (var i = 0; i < pool.length; i++) {
        final Uint8List? bytes = await pool[i]
            .asset
            .thumbnailDataWithSize(const ThumbnailSize(384, 384));
        if (bytes != null) {
          final cand = await _detectPose(detector, bytes);
          if (cand != null && cand.length >= 3) {
            final poseSim = _poseSimilarity(refPose, cand);
            if (poseSim >= minPose) {
              // 자세 80% + 시각 20%.
              final score =
                  (0.8 * poseSim + 0.2 * pool[i].visual).clamp(0.0, 1.0);
              matches.add(SimilarMatch(pool[i].asset, score));
            }
          }
        }
        onProgress?.call(0.4 + 0.6 * (i + 1) / pool.length);
      }
      matches.sort((a, b) => b.similarity.compareTo(a.similarity));
      onProgress?.call(1);
      return matches.length > topN ? matches.sublist(0, topN) : matches;
    } finally {
      await detector.close();
    }
  }

  /// 바이트 → 뼈 방향 단위벡터 맵(뼈이름 → [ux, uy]). 사람/포즈 없으면 빈 맵,
  /// 실패 시 null. 신뢰도 0.5 미만 관절은 제외.
  Future<Map<String, List<double>>?> _detectPose(
      PoseDetector detector, Uint8List bytes) async {
    File? tmp;
    try {
      final dir = await getTemporaryDirectory();
      tmp = File(p.join(dir.path, 'mlkit_pose_scan.jpg'));
      await tmp.writeAsBytes(bytes, flush: true);
      final poses =
          await detector.processImage(InputImage.fromFilePath(tmp.path));
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

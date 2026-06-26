import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
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

/// 얼굴 배치 요약 — 정규화된 [중심x, 중심y, 크기] 박스 목록.
class _FaceProfile {
  _FaceProfile(this.boxes);
  final List<List<double>> boxes; // 각 0~1 정규화
  int get count => boxes.length;
}

/// 후보 1건의 점수 상태.
class _Scored {
  _Scored(this.asset, this.visual) : score = visual;
  final AssetEntity asset;
  final double visual; // 1단계 시각 유사도
  double score; // 2단계 재랭킹 후 최종 점수
}

/// 갤러리를 뒤져 기준 사진과 비슷한(같은 포즈·장소·사람) 사진을 찾는다.
///
/// 메이저앱(구글/애플 포토)의 **2단계 파이프라인**을 온디바이스로 구현:
///  1. **Recall** — 썸네일 시그니처(dHash 구조 + 컬러 블록)로 수백 장을 빠르게 추려
///     상위 후보군을 만든다. 순수 Dart, 외부 서버/모델 없음.
///  2. **Rerank** — 상위 후보에만 **Google ML Kit 온디바이스 얼굴 검출**을 돌려
///     "같은 사람·비슷한 얼굴 배치"를 가중. 가족 사진에서 가장 중요한 신호다.
class SimilarPhotoFinder {
  const SimilarPhotoFinder();

  Future<bool> ensurePermission() async {
    final ps = await PhotoManager.requestPermissionExtend();
    return ps.isAuth || ps.hasAccess;
  }

  /// 기준 사진 바이트 [refBytes]와 비슷한 사진을 유사도 높은 순으로.
  ///
  /// [scanLimit] 최근 N장까지 1단계 스캔, [candidatePool] 상위 후보만 2단계 ML 재랭킹.
  /// [onProgress]는 0~1(1단계 70% + 2단계 30%).
  Future<List<SimilarMatch>> findSimilar(
    Uint8List refBytes, {
    int scanLimit = 600,
    int candidatePool = 40,
    int topN = 60,
    double minSimilarity = 0.6,
    void Function(double progress)? onProgress,
  }) async {
    final refSig = ImageHash.signatureOf(refBytes);
    if (refSig == null) return const [];

    // ── 1단계: recall — 갤러리 썸네일 시그니처로 빠르게 후보 추리기 ──
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
      if (i % 8 == 0) onProgress?.call(0.7 * (i + 1) / assets.length);
    }
    scored.sort((a, b) => b.visual.compareTo(a.visual));
    final pool = scored.take(candidatePool).toList();

    // ── 2단계: rerank — 상위 후보에만 ML 얼굴 검출 ──
    final detector = FaceDetector(
      options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
    );
    try {
      final refFace = await _detectProfile(detector, refBytes);
      final useFaces = refFace != null && refFace.count > 0;
      for (var i = 0; i < pool.length; i++) {
        if (useFaces) {
          final Uint8List? bytes = await pool[i]
              .asset
              .thumbnailDataWithSize(const ThumbnailSize(480, 480));
          if (bytes != null) {
            final candFace = await _detectProfile(detector, bytes);
            final fs = _faceScore(refFace, candFace);
            // 가족앱: 시각 50% + 얼굴 50% 결합.
            pool[i].score = 0.5 * pool[i].visual + 0.5 * fs;
          }
        }
        onProgress?.call(0.7 + 0.3 * (i + 1) / pool.length);
      }
    } catch (_) {
      // ML 실패 시 1단계 시각 점수로 graceful fallback (점수 그대로 유지).
    } finally {
      await detector.close();
    }

    onProgress?.call(1);
    final matches = pool
        .where((s) => s.score >= minSimilarity)
        .map((s) => SimilarMatch(s.asset, s.score))
        .toList()
      ..sort((a, b) => b.similarity.compareTo(a.similarity));
    return matches.length > topN ? matches.sublist(0, topN) : matches;
  }

  /// 바이트 → 얼굴 프로필(정규화 박스). 얼굴 없으면 빈 프로필, 실패 시 null.
  Future<_FaceProfile?> _detectProfile(
      FaceDetector detector, Uint8List bytes) async {
    File? tmp;
    try {
      final dir = await getTemporaryDirectory();
      tmp = File(p.join(dir.path, 'mlkit_face_scan.jpg'));
      await tmp.writeAsBytes(bytes, flush: true);
      final faces = await detector.processImage(InputImage.fromFilePath(tmp.path));
      if (faces.isEmpty) return _FaceProfile(const []);

      // 정규화 기준 이미지 크기.
      final decoded = img.decodeImage(bytes);
      final w = (decoded?.width ?? 1).toDouble();
      final h = (decoded?.height ?? 1).toDouble();
      final minDim = math.min(w, h);
      final boxes = <List<double>>[];
      for (final f in faces) {
        final r = f.boundingBox;
        boxes.add([
          r.center.dx / w,
          r.center.dy / h,
          (r.width.abs() / minDim).clamp(0.0, 1.0),
        ]);
      }
      // 큰 얼굴 우선 정렬(주 피사체부터 매칭).
      boxes.sort((a, b) => b[2].compareTo(a[2]));
      return _FaceProfile(boxes);
    } catch (_) {
      return null;
    } finally {
      try {
        await tmp?.delete();
      } catch (_) {}
    }
  }

  /// 두 얼굴 프로필 유사도(0~1) — 개수 일치 + 위치/크기 정렬 매칭.
  double _faceScore(_FaceProfile ref, _FaceProfile? cand) {
    if (cand == null || cand.count == 0) return 0.15; // 사람 없는 사진은 강한 패널티.
    final countSim =
        1 - (ref.count - cand.count).abs() / math.max(ref.count, cand.count);
    final n = math.min(ref.count, cand.count);
    var boxSum = 0.0;
    for (var i = 0; i < n; i++) {
      final a = ref.boxes[i];
      final b = cand.boxes[i];
      final dx = a[0] - b[0];
      final dy = a[1] - b[1];
      final posDist = math.sqrt(dx * dx + dy * dy) / 1.4142; // 0~1
      final sizeDist = (a[2] - b[2]).abs(); // 0~1
      boxSum += (1 - 0.7 * posDist - 0.3 * sizeDist).clamp(0.0, 1.0);
    }
    final boxScore = boxSum / n;
    // 개수 비중 크게, 위치/크기로 보정.
    return (countSim * (0.5 + 0.5 * boxScore)).clamp(0.0, 1.0);
  }
}

final similarPhotoFinderProvider =
    Provider<SimilarPhotoFinder>((ref) => const SimilarPhotoFinder());

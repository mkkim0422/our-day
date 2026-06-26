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

/// 얼굴 배치 요약 — 정규화된 [중심x, 중심y, 크기] 박스 목록(큰 얼굴 우선).
class _FaceProfile {
  _FaceProfile(this.boxes);
  final List<List<double>> boxes;
  int get count => boxes.length;
}

/// 후보 1건의 시각 점수.
class _Scored {
  _Scored(this.asset, this.visual);
  final AssetEntity asset;
  final double visual;
}

/// 갤러리를 뒤져 기준 사진과 비슷한 사진을 찾는다.
///
/// 메이저앱(구글/애플 포토) 방식 참고 — "비슷한 사진"의 핵심 신호는 **사람(얼굴)**:
///  - 기준 사진에 **얼굴이 있으면**: 얼굴 검출로 후보를 걸러 **얼굴이 있는 사진만**
///    반환하고, 얼굴 개수·위치·크기 정합 + 시각 유사도로 재랭킹한다.
///    (얼굴 없는 사진이 추천되는 문제를 원천 차단)
///  - 얼굴이 없으면: 시각 시그니처(dHash 구조 + 컬러 블록)로만 정렬.
///
/// 같은 "사람(인물 동일성)"까지 매칭하려면 얼굴 임베딩(MobileFaceNet/FaceNet,
/// 코사인 유사도)이 필요하다 — 후속 업그레이드 대상. 현재는 얼굴 검출(ML Kit)
/// 기반 게이팅·배치 정합으로 온디바이스에서 동작한다.
class SimilarPhotoFinder {
  const SimilarPhotoFinder();

  Future<bool> ensurePermission() async {
    final ps = await PhotoManager.requestPermissionExtend();
    return ps.isAuth || ps.hasAccess;
  }

  /// 기준 사진 바이트 [refBytes]와 비슷한 사진을 유사도 높은 순으로.
  ///
  /// [onProgress]는 0~1. 얼굴 모드일 땐 0~0.4 recall + 0.4~1 얼굴 분석.
  Future<List<SimilarMatch>> findSimilar(
    Uint8List refBytes, {
    int scanLimit = 600,
    int facePool = 120, // 얼굴 모드에서 얼굴 검출할 시각 상위 후보 수
    int topN = 60,
    double minVisual = 0.5,
    void Function(double progress)? onProgress,
  }) async {
    final refSig = ImageHash.signatureOf(refBytes);
    if (refSig == null) return const [];

    final detector = FaceDetector(
      options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
    );
    try {
      // 기준 사진 얼굴 검출 → 모드 결정.
      final refFace = await _detectProfile(detector, refBytes);
      final faceMode = refFace != null && refFace.count > 0;

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

      // ── 1단계 recall: 시각 시그니처 ──
      final recallSpan = faceMode ? 0.4 : 1.0;
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

      // 얼굴 없는 기준: 시각 유사도로만.
      if (!faceMode) {
        onProgress?.call(1);
        return scored
            .where((s) => s.visual >= minVisual)
            .take(topN)
            .map((s) => SimilarMatch(s.asset, s.visual))
            .toList();
      }

      // ── 2단계: 얼굴 게이팅 + 재랭킹 (얼굴 있는 사진만 통과) ──
      final pool = scored.take(facePool).toList();
      final matches = <SimilarMatch>[];
      for (var i = 0; i < pool.length; i++) {
        final Uint8List? bytes = await pool[i]
            .asset
            .thumbnailDataWithSize(const ThumbnailSize(320, 320));
        if (bytes != null) {
          final cf = await _detectProfile(detector, bytes);
          if (cf != null && cf.count > 0) {
            final align = _faceAlign(refFace, cf);
            // 얼굴 정합 55% + 시각 45% — 기준마다 순위가 달라지도록 시각도 반영.
            final score = (0.55 * align + 0.45 * pool[i].visual).clamp(0.0, 1.0);
            matches.add(SimilarMatch(pool[i].asset, score));
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

  /// 바이트 → 얼굴 프로필(정규화 박스). 얼굴 없으면 빈 프로필, 실패 시 null.
  Future<_FaceProfile?> _detectProfile(
      FaceDetector detector, Uint8List bytes) async {
    File? tmp;
    try {
      final dir = await getTemporaryDirectory();
      tmp = File(p.join(dir.path, 'mlkit_face_scan.jpg'));
      await tmp.writeAsBytes(bytes, flush: true);
      final faces =
          await detector.processImage(InputImage.fromFilePath(tmp.path));
      if (faces.isEmpty) return _FaceProfile(const []);

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
      boxes.sort((a, b) => b[2].compareTo(a[2])); // 큰 얼굴 우선.
      return _FaceProfile(boxes);
    } catch (_) {
      return null;
    } finally {
      try {
        await tmp?.delete();
      } catch (_) {}
    }
  }

  /// 두 얼굴 프로필 정합도(0~1) — 개수 일치 + 위치/크기 매칭.
  double _faceAlign(_FaceProfile ref, _FaceProfile cand) {
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
    final boxScore = n > 0 ? boxSum / n : 0.0;
    return (countSim * (0.5 + 0.5 * boxScore)).clamp(0.0, 1.0);
  }
}

final similarPhotoFinderProvider =
    Provider<SimilarPhotoFinder>((ref) => const SimilarPhotoFinder());

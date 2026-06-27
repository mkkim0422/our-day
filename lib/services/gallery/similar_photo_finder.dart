import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

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

  /// '전체 검색'이 훑을 장수(상한 적용). 포즈검출은 장당 ~0.1초라 무한정 못 본다 →
  /// 시간대별로 펼쳐 최대 1,500장까지(약 2분). 그 이상은 사용자가 다시 돌리면 된다.
  int get fullCount => math.min(total, 1500);

  /// 기준 포즈 검출 등 고정 오버헤드(초).
  static const double _fixedSec = 3;

  Duration estimate(int count) {
    final sec = _fixedSec + (msPerPhoto * count) / 1000.0;
    return Duration(milliseconds: (sec * 1000).round());
  }

  Duration get quickEstimate => estimate(quickCount);
  Duration get fullEstimate => estimate(fullCount);
}

/// 사진 한 장의 **사람 구도** 서명. 배경·색은 보지 않는다.
///  - [count] 프레임 안 사람 수(얼굴 개수).
///  - [xSpread]/[ySpread] 얼굴들이 가로/세로로 퍼진 정도(0~1) — "나란히"(가로 넓음)
///    vs "모여 앉음"(좁음) vs "혼자"(0)를 구분.
///  - [avgSize] 평균 얼굴 크기(0~1) — 전신 단체샷(작음) vs 클로즈업(큼).
///  - [pose] 대표 인물의 뼈 방향(서있음/앉음/브이 구분용, 없으면 빈 맵).
class _Composition {
  _Composition(
      this.count, this.xSpread, this.ySpread, this.avgSize, this.pose);
  final int count;
  final double xSpread;
  final double ySpread;
  final double avgSize;
  final Map<String, List<double>> pose;
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

/// 갤러리를 뒤져 기준 사진과 **사람 구도가 비슷한** 사진을 찾는다.
///
/// 이 앱은 "같은 구도로 주기적으로 찍어 변화를 보는" 가족사진 앱이다. 그래서 핵심
/// 신호는 배경·색이 아니라 **프레임 안 사람들의 구도** — 몇 명이, 어떻게 배치돼
/// (나란히/모여/혼자), 어떤 자세인지. 모두 무료·온디바이스 ML Kit으로 추출한다.
///
/// 설계(구도 우선):
///  1. **얼굴검출**로 사람 수와 화면 내 배치(가로/세로 퍼짐, 크기)를 잡고,
///     **포즈검출**로 대표 인물의 자세(서있음/앉음/브이)를 잡아 [_Composition] 서명을 만든다.
///  2. 기준 사진에 사람(얼굴)이 없으면 비교 기준이 없어 검색 불가(→ 빈 결과).
///  3. 시간대별로 펼친 후보마다 같은 서명을 만들어, **사람 수(45%) + 배치(30%) +
///     자세(25%)** 로 유사도를 매긴다. **사람이 없는 사진(컴퓨터·풍경·물건)은 제외.**
///
/// 한계: 얼굴+포즈 검출이 장당 ~0.1초라 수만 장을 한 번에 못 본다 → 시간대별 분산
/// 표본 수백~1,500장을 검사한다. ML Kit 기본 포즈는 대표 1명만 보므로 자세는 보조
/// 신호다(전원 자세가 필요하면 멀티포즈 모델로 확장).
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
    return GallerySurvey(
        total: total, msPerPhoto: ms, quickCount: math.min(total, 500));
  }

  /// 장당 처리시간(ms)을 **실제 검색과 동일한 경로**(512px 썸네일 + ML Kit 얼굴+포즈
  /// 검출)로 표본 몇 장에 대해 실측한다. 검출이 병목(장당 ~0.1초)이므로 이걸 재야
  /// 예측이 맞는다. 표본 없으면 보수적 폴백.
  Future<double> _probeMsPerPhoto(List<AssetEntity> sample) async {
    if (sample.isEmpty) return 120;
    final pose = PoseDetector(
        options: PoseDetectorOptions(mode: PoseDetectionMode.single));
    final face = FaceDetector(
        options: FaceDetectorOptions(
            performanceMode: FaceDetectorMode.fast, minFaceSize: 0.04));
    final tmpDir = await getTemporaryDirectory();
    try {
      final probe = sample.take(8).toList(); // 검출은 느리니 8장만 표본.
      final sw = Stopwatch()..start();
      var n = 0;
      for (final a in probe) {
        final b = await _safeThumb(a, 512);
        if (b == null) continue;
        await _detectComposition(pose, face, b, tmpDir);
        n++;
      }
      sw.stop();
      if (n == 0) return 120;
      // 실측에 여유(15%)를 더해 과소예측 방지(콜드 캐시 등).
      return (sw.elapsedMilliseconds / n) * 1.15;
    } finally {
      await pose.close().timeout(const Duration(seconds: 5), onTimeout: () {});
      await face.close().timeout(const Duration(seconds: 5), onTimeout: () {});
    }
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

  /// 기준 사진 바이트 [refBytes]와 **비슷한 자세**의 사진을 유사도 높은 순으로.
  ///
  /// 포즈 우선: 스캔하는 모든 후보에 ML Kit 포즈검출을 직접 돌리고, 사람/자세가 없는
  /// 사진은 제외한다. [onProgress]는 0~1(스캔 진행도). 결과는 자세 유사도순.
  Future<List<SimilarMatch>> findSimilar(
    Uint8List refBytes, {
    // 포즈검출은 장당 ~0.1초라 수만 장을 못 본다. 시간대별로 펼친 [scanLimit]장만
    // 검사한다(전 기간 분산 → 연도별 타임랩스에 과거 사진도 닿게).
    int scanLimit = 500,
    int topN = 60,
    // 이 미만 구도 유사도는 "다른 구도"로 보고 제외.
    double compFloor = 0.6,
    // 안전 상한(무한 멈춤 방지). 평소엔 isCancelled/scanLimit가 먼저 끝낸다.
    Duration budget = const Duration(minutes: 20),
    // 사용자가 '중지'를 누르면 true → 즉시 멈추고 최선결과 반환.
    bool Function()? isCancelled,
    void Function(double progress)? onProgress,
    // 스캔한 장수/계획 장수 — "120 / 500장 · 약 30초 남음" 표시용.
    void Function(int scanned, int planned)? onScanned,
    // 매칭이 나오는 즉시 화면에 흘려보낸다(점진 표시) → 빈 스피너로 안 기다리게.
    void Function(List<SimilarMatch> partial)? onPartial,
  }) async {
    final clock = Stopwatch()..start();
    bool stop() => clock.elapsed >= budget || (isCancelled?.call() ?? false);

    final pose = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.single),
    );
    final face = FaceDetector(
      // minFaceSize 작게 → 단체샷·전신샷의 작은 얼굴도 잡는다(기본 0.1은 놓침).
      options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.fast, minFaceSize: 0.04),
    );
    try {
      onProgress?.call(0.01); // 즉시 움직임(0%에 갇힌 것처럼 안 보이게).
      final tmpDir = await getTemporaryDirectory();

      // ── 기준 구도 먼저 ── 사람(얼굴)이 없으면 비교 기준이 없어 검색 불가.
      // (배경·색은 보지 않는다 — 구도와 무관해 엉뚱한 사진을 불러왔다.)
      final refComp = await _detectComposition(pose, face, refBytes, tmpDir);
      if (refComp == null) return const [];
      debugPrint('[comp] ref count=${refComp.count} '
          'xS=${refComp.xSpread.toStringAsFixed(2)} '
          'yS=${refComp.ySpread.toStringAsFixed(2)} '
          'sz=${refComp.avgSize.toStringAsFixed(2)} poseBones=${refComp.pose.length}');

      // 갤러리 앨범 목록 — 네이티브 호출이라 타임아웃으로 감싼다.
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      ).timeout(const Duration(seconds: 10),
          onTimeout: () => <AssetPathEntity>[]);
      if (paths.isEmpty) return const [];
      final all = paths.first;

      // 총 장수·범위 조회도 만장 갤러리에선 느릴 수 있어 타임아웃 필수.
      final total = await all.assetCountAsync
          .timeout(const Duration(seconds: 8), onTimeout: () => 0);
      if (total == 0) return const [];
      // 최신 N장이 아니라 **전 기간에 분산**해 가져온다(연도별 커버리지).
      final assets = await _collectSpread(all, total, math.min(total, scanLimit));
      if (assets.isEmpty) return const [];

      // ── 후보마다 얼굴+포즈 검출 → 사람 구도 유사도 ──
      // 썸네일은 6장씩 동시에 받아두고(플랫폼 채널), 검출은 순차로(한 인스턴스).
      // 사람이 없는 사진은 추가하지 않는다 → 컴퓨터·풍경·물건 사진 자동 제외.
      final matches = <SimilarMatch>[];
      const fetch = 6;
      for (var start = 0; start < assets.length; start += fetch) {
        if (stop()) break;
        final end = math.min(start + fetch, assets.length);
        final sub = assets.sublist(start, end);
        final thumbs = await Future.wait(sub.map((a) => _safeThumb(a, 512)));
        for (var k = 0; k < sub.length; k++) {
          if (stop()) break;
          final b = thumbs[k];
          if (b == null) continue;
          final comp = await _detectComposition(pose, face, b, tmpDir);
          if (comp == null) continue; // 사람 없음 → 제외.
          final sim = _compositionSimilarity(refComp, comp);
          if (sim >= compFloor) matches.add(SimilarMatch(sub[k], sim));
        }
        onProgress?.call(0.01 + 0.98 * end / assets.length);
        onScanned?.call(end, assets.length);
        // 지금까지의 best를 점진 표시.
        matches.sort((a, b) => b.similarity.compareTo(a.similarity));
        onPartial?.call(
            matches.length > topN ? matches.sublist(0, topN) : List.of(matches));
        await Future<void>.delayed(Duration.zero);
      }

      matches.sort((a, b) => b.similarity.compareTo(a.similarity));
      onProgress?.call(1);
      final result = matches.length > topN ? matches.sublist(0, topN) : matches;
      onPartial?.call(result);
      debugPrint('[comp] kept=${matches.length} top='
          '${result.take(8).map((m) => m.similarity.toStringAsFixed(2)).toList()}');
      return result;
    } finally {
      // close()도 네이티브 호출 — 손상된 ML Kit에서 멈추지 않도록 타임아웃.
      await pose.close().timeout(const Duration(seconds: 5), onTimeout: () {});
      await face.close().timeout(const Duration(seconds: 5), onTimeout: () {});
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

  /// 바이트 → **사람 구도 서명**([_Composition]). 사람(얼굴)이 없으면 null → 결과 제외.
  ///
  /// 임시 파일에 한 번만 써서 얼굴+포즈 검출을 같은 이미지에 돌린다(IO 절약).
  Future<_Composition?> _detectComposition(PoseDetector poseDet,
      FaceDetector faceDet, Uint8List bytes, Directory tmpDir) async {
    File? tmp;
    try {
      tmp = File(p.join(tmpDir.path, 'mlkit_scan.jpg'));
      await tmp.writeAsBytes(bytes, flush: true);
      final input = InputImage.fromFilePath(tmp.path);

      // 이미지 픽셀 크기(헤더만 읽어 정규화용 — 전체 디코딩 안 함).
      double w = 0, h = 0;
      try {
        final buf = await ui.ImmutableBuffer.fromUint8List(bytes);
        final desc = await ui.ImageDescriptor.encoded(buf);
        w = desc.width.toDouble();
        h = desc.height.toDouble();
        desc.dispose();
        buf.dispose();
      } catch (_) {}
      if (w <= 0 || h <= 0) return null;

      // 얼굴(사람 수·배치) — 타임아웃으로 멈춤 방지.
      final faces = await faceDet
          .processImage(input)
          .timeout(const Duration(seconds: 8), onTimeout: () => const <Face>[]);
      if (faces.isEmpty) return null; // 사람 없음 → 제외.
      var minX = 1.0, maxX = 0.0, minY = 1.0, maxY = 0.0, sizeSum = 0.0;
      for (final f in faces) {
        final r = f.boundingBox;
        final cx = ((r.left + r.width / 2) / w).clamp(0.0, 1.0);
        final cy = ((r.top + r.height / 2) / h).clamp(0.0, 1.0);
        minX = math.min(minX, cx);
        maxX = math.max(maxX, cx);
        minY = math.min(minY, cy);
        maxY = math.max(maxY, cy);
        sizeSum += (r.width / w).clamp(0.0, 1.0);
      }
      final xSpread = faces.length > 1 ? maxX - minX : 0.0;
      final ySpread = faces.length > 1 ? maxY - minY : 0.0;
      final avgSize = sizeSum / faces.length;

      // 대표 인물 자세(서있음/앉음/브이 구분). 못 잡으면 빈 맵.
      final pose = await _bonesFromImage(poseDet, input);
      return _Composition(faces.length, xSpread, ySpread, avgSize, pose);
    } catch (_) {
      return null;
    } finally {
      try {
        await tmp?.delete();
      } catch (_) {}
    }
  }

  /// InputImage → 대표 인물의 뼈 방향 단위벡터 맵(뼈이름 → [ux, uy]).
  /// 사람/포즈 없거나 실패 시 빈 맵. 신뢰도 0.5 미만 관절은 제외.
  Future<Map<String, List<double>>> _bonesFromImage(
      PoseDetector detector, InputImage input) async {
    try {
      final poses = await detector
          .processImage(input)
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
      return <String, List<double>>{};
    }
  }

  /// 두 사진의 **사람 구도 유사도**(0~1): 사람 수(45%) + 배치(30%) + 자세(25%).
  /// 사람 수가 2명 이상 차이나면 다른 구도로 보고 0.
  double _compositionSimilarity(_Composition r, _Composition c) {
    final dc = (r.count - c.count).abs();
    final countScore = dc == 0
        ? 1.0
        : dc == 1
            ? 0.4
            : 0.0;
    if (countScore == 0) return 0;
    // 배치: 가로/세로 퍼짐 + 평균 얼굴 크기 패턴이 비슷할수록 1.
    final arr = (1.0 -
            ((r.xSpread - c.xSpread).abs() +
                    (r.ySpread - c.ySpread).abs() +
                    (r.avgSize - c.avgSize).abs()) /
                3)
        .clamp(0.0, 1.0);
    // 자세: 양쪽 다 대표 자세가 잡혔을 때만. 한쪽이라도 없으면 중립(0.5).
    final poseScore = (r.pose.length >= 3 && c.pose.length >= 3)
        ? _poseSimilarity(r.pose, c.pose)
        : 0.5;
    return (0.45 * countScore + 0.30 * arr + 0.25 * poseScore)
        .clamp(0.0, 1.0);
  }

  /// 두 자세의 유사도(0~1) — 공통 뼈들의 방향 코사인 **가중 평균**. 공통 뼈 3개 미만 0.
  ///
  /// **팔 뼈(어깨→팔꿈치, 팔꿈치→손목)에 큰 가중치**를 준다. 서 있는 사람은 몸통·다리
  /// 뼈가 다 비슷해서, 동일 가중이면 "그냥 선 사진"과 "브이 한 사진"이 똑같이 높게 나온다.
  /// 팔을 강조해야 "브이·팔 든 자세"가 "팔 내린 자세"보다 위로 온다(사용자 의도).
  double _poseSimilarity(
      Map<String, List<double>> a, Map<String, List<double>> b) {
    var sum = 0.0;
    var wsum = 0.0;
    var n = 0;
    for (final key in a.keys) {
      final vb = b[key];
      if (vb == null) continue;
      final va = a[key]!;
      final w = _armBones.contains(key) ? 3.0 : 1.0;
      final cos = (va[0] * vb[0] + va[1] * vb[1]).clamp(-1.0, 1.0);
      sum += w * (cos + 1) / 2; // [-1,1] → [0,1]
      wsum += w;
      n++;
    }
    if (n < 3 || wsum == 0) return 0;
    return (sum / wsum).clamp(0.0, 1.0);
  }
}

/// 팔 뼈 키(_bonesFromImage의 '${a.name}_${b.name}' 형식) — 자세 비교에서 가중된다.
const _armBones = <String>{
  'leftShoulder_leftElbow',
  'leftElbow_leftWrist',
  'rightShoulder_rightElbow',
  'rightElbow_rightWrist',
};

final similarPhotoFinderProvider =
    Provider<SimilarPhotoFinder>((ref) => const SimilarPhotoFinder());

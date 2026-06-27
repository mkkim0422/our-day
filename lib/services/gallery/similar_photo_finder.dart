import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
/// 이 앱은 "같은 포즈로 주기적으로 찍는" 가족사진 앱이다. 핵심 신호는 인물 동일성이
/// 아니라 **자세**다. Google ML Kit **포즈 추정**(무료·온디바이스)으로 관절 키포인트를
/// 뽑아, 연결된 관절의 **방향 벡터(뼈 각도)** 로 정규화해 비교한다 — 위치·크기에
/// 무관하게 "자세가 얼마나 닮았는지"만 본다.
///
/// 설계(포즈 우선):
///  1. 기준 사진의 포즈를 먼저 검출. 사람/자세가 없으면 검색 불가(→ 빈 결과).
///  2. 시간대별로 펼친 후보 각각에 **실제로 포즈검출**을 돌린다(색·밝기 해시로
///     후보를 고르지 않는다 — 그건 자세와 무관해 엉뚱한 사진을 불러왔다).
///  3. **사람/자세가 없는 사진(컴퓨터·풍경·물건)은 결과에서 완전히 제외.**
///  4. **팔(어깨→팔꿈치→손목) 뼈에 가중치**를 줘 "브이·팔 든 자세"가 위로 오게,
///     자세 유사도만으로 정렬.
///
/// 한계: 포즈검출은 장당 ~0.1초라 수만 장을 한 번에 못 본다 → 시간대별 분산 표본
/// 수백~1,500장을 검사한다. 검사한 것 중에선 정확히 자세가 비슷한 것만 나온다.
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

  /// 장당 처리시간(ms)을 **실제 검색과 동일한 경로**(512px 썸네일 + ML Kit 포즈검출)로
  /// 표본 몇 장에 대해 실측한다. 포즈검출이 병목(장당 ~0.1초)이므로 이걸 재야 예측이
  /// 맞는다. 표본 없으면 보수적 폴백.
  Future<double> _probeMsPerPhoto(List<AssetEntity> sample) async {
    if (sample.isEmpty) return 100;
    final detector = PoseDetector(
        options: PoseDetectorOptions(mode: PoseDetectionMode.single));
    final tmpDir = await getTemporaryDirectory();
    try {
      final probe = sample.take(8).toList(); // 포즈는 느리니 8장만 표본.
      final sw = Stopwatch()..start();
      var n = 0;
      for (final a in probe) {
        final b = await _safeThumb(a, 512);
        if (b == null) continue;
        await _detectPose(detector, b, tmpDir);
        n++;
      }
      sw.stop();
      if (n == 0) return 100;
      // 실측에 여유(15%)를 더해 과소예측 방지(콜드 캐시 등).
      return (sw.elapsedMilliseconds / n) * 1.15;
    } finally {
      await detector.close().timeout(const Duration(seconds: 5), onTimeout: () {});
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
    // 이 미만 자세 유사도는 "다른 자세"로 보고 제외. 팔 자세 가중 후 기준.
    double poseFloor = 0.6,
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

    final detector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.single),
    );
    try {
      onProgress?.call(0.01); // 즉시 움직임(0%에 갇힌 것처럼 안 보이게).
      final tmpDir = await getTemporaryDirectory();

      // ── 기준 포즈 먼저 ── 사람/자세가 없으면 비교 기준이 없어 검색 불가.
      // (색·밝기 매칭은 하지 않는다 — 자세와 무관해 엉뚱한 사진을 불러왔다.)
      final refPose = await _detectPose(detector, refBytes, tmpDir);
      if (refPose == null || refPose.length < 3) return const [];

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

      // ── 후보마다 실제 포즈검출 → 자세 유사도 ──
      // 썸네일은 6장씩 동시에 받아두고(플랫폼 채널), 포즈검출은 순차로(한 인스턴스).
      // 사람/자세가 없는 사진은 추가하지 않는다 → 컴퓨터·풍경·물건 사진 자동 제외.
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
          final pose = await _detectPose(detector, b, tmpDir);
          if (pose == null || pose.length < 3) continue; // 사람/자세 없음 → 제외.
          final sim = _poseSimilarity(refPose, pose);
          if (sim >= poseFloor) matches.add(SimilarMatch(sub[k], sim));
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
      return result;
    } finally {
      // close()도 네이티브 호출 — 손상된 ML Kit에서 멈추지 않도록 타임아웃.
      await detector.close().timeout(const Duration(seconds: 5),
          onTimeout: () {});
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

/// 팔 뼈 키(_detectPose의 '${a.name}_${b.name}' 형식) — 자세 비교에서 가중된다.
const _armBones = <String>{
  'leftShoulder_leftElbow',
  'leftElbow_leftWrist',
  'rightShoulder_rightElbow',
  'rightElbow_rightWrist',
};

final similarPhotoFinderProvider =
    Provider<SimilarPhotoFinder>((ref) => const SimilarPhotoFinder());

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
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

  /// '전체 검색'이 훑을 장수(상한 적용). 얼굴검출은 장당 ~0.05초라 무한정 못 본다 →
  /// 시간대별로 펼쳐 최대 2,000장까지. 그 이상은 사용자가 다시 돌리면 된다.
  int get fullCount => math.min(total, 2000);

  /// 기준 포즈 검출 등 고정 오버헤드(초).
  static const double _fixedSec = 3;

  Duration estimate(int count) {
    final sec = _fixedSec + (msPerPhoto * count) / 1000.0;
    return Duration(milliseconds: (sec * 1000).round());
  }

  Duration get quickEstimate => estimate(quickCount);
  Duration get fullEstimate => estimate(fullCount);
}

/// 사진 한 장의 **사람 구도** 서명. 배경·색·자세는 보지 않는다.
///
/// [faces] = 화면 내 각 얼굴의 `[정규화 중심x, 중심y, 크기]`, **좌→우(중심x) 정렬**.
/// 사람 수(faces.length)와 **각 사람이 프레임 어디에 어떤 크기로 있는지**(= 구도)를
/// 그대로 담는다. "3명이 나란히 선" 구도면 [작은 얼굴 3개가 비슷한 높이로 가로 배치].
class _Composition {
  _Composition(this.faces);

  /// 정규화 얼굴 목록 `[cx, cy, size]`, 좌→우 정렬.
  final List<List<double>> faces;

  int get count => faces.length;
}

/// 갤러리를 뒤져 기준 사진과 **사람 구도가 비슷한** 사진을 찾는다.
///
/// 이 앱은 "같은 구도로 주기적으로 찍어 변화를 보는" 가족사진 앱이다. 그래서 핵심
/// 신호는 배경·색·자세가 아니라 **인원수 + 프레임 안 사람들의 배치(구도)** 다.
///
/// 설계(인원수 + 구도):
///  1. **얼굴검출**(무료·온디바이스 ML Kit)로 사람 수와 각 얼굴의 위치·크기를 잡아
///     [_Composition] 서명을 만든다.
///  2. 기준 사진에 사람(얼굴)이 없으면 비교 기준이 없어 검색 불가(→ 빈 결과).
///  3. 후보마다 같은 서명을 만들어 **인원수(같아야 함) + 얼굴 배치 유사도**로 매긴다.
///     **사람 없는 사진·흑백(만화·문서)은 제외.** 자세(포즈)는 보지 않는다 — 사용자가
///     원하는 건 "사진 전체 구도"이지 특정 자세(브이 등)가 아니다.
///
/// 한계: 얼굴검출이 장당 ~0.05초라 수만 장을 한 번에 못 본다 → 시간대별 분산 표본
/// 수백~2,000장을 검사한다.
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
        total: total, msPerPhoto: ms, quickCount: math.min(total, 700));
  }

  /// 장당 처리시간(ms)을 **실제 검색과 동일한 경로**(512px 썸네일 + ML Kit 얼굴검출)로
  /// 표본 몇 장에 대해 실측한다. 검출이 병목이므로 이걸 재야 예측이 맞는다.
  /// 표본 없으면 보수적 폴백.
  Future<double> _probeMsPerPhoto(List<AssetEntity> sample) async {
    if (sample.isEmpty) return 70;
    final face = FaceDetector(
        options: FaceDetectorOptions(
            performanceMode: FaceDetectorMode.fast, minFaceSize: 0.04));
    final tmpDir = await getTemporaryDirectory();
    try {
      final probe = sample.take(8).toList();
      final sw = Stopwatch()..start();
      var n = 0;
      for (final a in probe) {
        final b = await _safeThumb(a, 512);
        if (b == null) continue;
        await _detectComposition(face, b, tmpDir);
        n++;
      }
      sw.stop();
      if (n == 0) return 70;
      // 실측에 여유(15%)를 더해 과소예측 방지(콜드 캐시 등).
      return (sw.elapsedMilliseconds / n) * 1.15;
    } finally {
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
    double compFloor = 0.65,
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

    final face = FaceDetector(
      // minFaceSize 작게 → 단체샷·전신샷의 작은 얼굴도 잡는다(기본 0.1은 놓침).
      options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.fast, minFaceSize: 0.04),
    );
    try {
      onProgress?.call(0.01); // 즉시 움직임(0%에 갇힌 것처럼 안 보이게).
      final tmpDir = await getTemporaryDirectory();

      // ── 기준 구도 먼저 ── 사람(얼굴)이 없으면 비교 기준이 없어 검색 불가.
      // (배경·색·자세는 보지 않는다 — 인원수+배치만 본다.)
      final refComp = await _detectComposition(face, refBytes, tmpDir);
      if (refComp == null) return const [];
      debugPrint('[comp] ref count=${refComp.count} '
          'faces=${refComp.faces.map((f) => f.map((v) => v.toStringAsFixed(2)).toList()).toList()}');

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

      // ── 후보마다 얼굴검출 → 사람 구도 유사도 ──
      // 썸네일은 6장씩 동시에 받아두고(플랫폼 채널), 검출은 순차로(한 인스턴스).
      // 사람이 없는 사진·흑백은 추가하지 않는다 → 컴퓨터·풍경·물건·만화 자동 제외.
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
          final comp = await _detectComposition(face, b, tmpDir);
          if (comp == null) continue; // 사람 없음/흑백 → 제외.
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
  /// 임시 파일에 한 번 써서 얼굴검출을 돌린다. 흑백·무인물은 null.
  Future<_Composition?> _detectComposition(
      FaceDetector faceDet, Uint8List bytes, Directory tmpDir) async {
    File? tmp;
    try {
      tmp = File(p.join(tmpDir.path, 'mlkit_scan.jpg'));
      await tmp.writeAsBytes(bytes, flush: true);
      final input = InputImage.fromFilePath(tmp.path);

      // 이미지 픽셀 크기(정규화용) + 평균 채도(흑백 거르기)를 한 번에 구한다.
      double w = 0, h = 0;
      double sat = 1.0; // 측정 실패 시 컬러로 간주(거르지 않음).
      try {
        final buf = await ui.ImmutableBuffer.fromUint8List(bytes);
        final desc = await ui.ImageDescriptor.encoded(buf);
        w = desc.width.toDouble();
        h = desc.height.toDouble();
        // 24x24로 작게 디코딩해 평균 채도 측정.
        final codec =
            await desc.instantiateCodec(targetWidth: 24, targetHeight: 24);
        final frame = await codec.getNextFrame();
        final bd =
            await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
        frame.image.dispose();
        codec.dispose();
        desc.dispose();
        buf.dispose();
        if (bd != null) sat = _meanSaturation(bd.buffer.asUint8List());
      } catch (_) {}
      if (w <= 0 || h <= 0) return null;
      // 흑백/저채도 = 만화·웹툰(흑백)·문서·텍스트 캡처일 가능성 → 가족사진 아님.
      // ML Kit 얼굴검출이 만화 속 그려진 얼굴까지 잡아 오매칭하던 문제를 막는다.
      if (sat < 0.08) return null;

      // 얼굴(사람 수·위치·크기) — 타임아웃으로 멈춤 방지.
      final faces = await faceDet
          .processImage(input)
          .timeout(const Duration(seconds: 8), onTimeout: () => const <Face>[]);
      if (faces.isEmpty) return null; // 사람 없음 → 제외.
      final list = <List<double>>[];
      for (final f in faces) {
        final r = f.boundingBox;
        final cx = ((r.left + r.width / 2) / w).clamp(0.0, 1.0);
        final cy = ((r.top + r.height / 2) / h).clamp(0.0, 1.0);
        final sz = (r.width / w).clamp(0.0, 1.0);
        list.add([cx, cy, sz]);
      }
      list.sort((a, b) => a[0].compareTo(b[0])); // 좌→우 정렬(짝짓기 기준).
      return _Composition(list);
    } catch (_) {
      return null;
    } finally {
      try {
        await tmp?.delete();
      } catch (_) {}
    }
  }

  /// RGBA 픽셀의 평균 채도(0~1). 0에 가까우면 흑백(만화·문서·텍스트 캡처).
  double _meanSaturation(Uint8List px) {
    if (px.length < 4) return 1.0;
    var sum = 0.0;
    var n = 0;
    for (var i = 0; i + 2 < px.length; i += 4) {
      final r = px[i], g = px[i + 1], b = px[i + 2];
      final mx = math.max(r, math.max(g, b));
      final mn = math.min(r, math.min(g, b));
      if (mx > 0) sum += (mx - mn) / mx;
      n++;
    }
    return n == 0 ? 1.0 : sum / n;
  }

  /// 두 사진의 **사람 구도 유사도**(0~1) = 인원수 + 얼굴 배치(위치·크기).
  ///
  /// 1) **인원수**가 먼저 맞아야 한다(다른 인원수 = 다른 구도). 정확히 같으면 만점,
  ///    1명 차이는 큰 감점, 2명 이상 차이는 0.
  /// 2) 같은 인원수면 얼굴들을 **좌→우 순서로 짝지어** 위치·크기 차이로 배치를 비교한다.
  ///    "3명이 비슷한 위치·크기로 있는" 구도끼리 높게 나온다. 자세(포즈)는 보지 않는다.
  double _compositionSimilarity(_Composition r, _Composition c) {
    final dc = (r.count - c.count).abs();
    final countFactor = dc == 0
        ? 1.0
        : dc == 1
            ? 0.4
            : 0.0;
    if (countFactor == 0) return 0;

    final n = math.min(r.faces.length, c.faces.length);
    if (n == 0) return 0;
    var posDist = 0.0; // 짝지은 얼굴 중심의 평균 거리(0~약1.41).
    var sizeDist = 0.0; // 짝지은 얼굴 크기의 평균 차(0~1).
    for (var i = 0; i < n; i++) {
      final a = r.faces[i], b = c.faces[i];
      final dx = a[0] - b[0], dy = a[1] - b[1];
      posDist += math.sqrt(dx * dx + dy * dy);
      sizeDist += (a[2] - b[2]).abs();
    }
    posDist /= n;
    sizeDist /= n;
    // 위치가 핵심(75%), 크기 보조(25%). 거리가 작을수록 1에 가깝게.
    final layout = (0.75 * (1 - posDist / 0.5) + 0.25 * (1 - sizeDist / 0.3))
        .clamp(0.0, 1.0);
    return (countFactor * layout).clamp(0.0, 1.0);
  }
}

final similarPhotoFinderProvider =
    Provider<SimilarPhotoFinder>((ref) => const SimilarPhotoFinder());

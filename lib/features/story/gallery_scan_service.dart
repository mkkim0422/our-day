import 'dart:math' as math;

import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

import 'story_index_cache.dart';
import 'story_models.dart';

/// 스캔 결과 요약(미리보기 진단용).
class GalleryScanResult {
  const GalleryScanResult({
    required this.photos,
    required this.totalInGallery,
    required this.newlyIndexed,
  });

  final List<StoryPhoto> photos;
  final int totalInGallery;

  /// 이번에 처음 GPS를 읽은 사진 수(캐시에 없던 새 사진). 0이면 전부 캐시에서.
  final int newlyIndexed;

  int get scanned => photos.length;
  int get withLocation => photos.where((p) => p.hasLocation).length;
}

/// 폰 갤러리를 훑어 스토리 입력(날짜·GPS)을 만든다(photo_manager).
///
/// 갤럭시식 **1회 색인 + 증분**: GPS(파일에서 읽어 느림)는 [StoryIndexCache]에
/// 저장해 두고, 다음부터는 캐시에 없는 **새 사진만** 읽는다. 촬영일은 AssetEntity
/// 에서 바로 얻으므로 매번 전체를 훑어도 빠르다(삭제된 사진은 자연히 정리됨).
///
/// 첫 스캔이 느린 원인은 사진마다 GPS를 파일에서 읽는 비용이라, 순차가 아니라
/// **여러 장 동시(_kConcurrency)** 로 읽어 수천 장도 1분 안팎으로 끝낸다.
class GalleryScanService {
  const GalleryScanService();

  final _cache = const StoryIndexCache();

  /// GPS를 동시에 읽는 사진 수. 플랫폼 채널 IO 대기이므로 병렬이 크게 빠르다.
  static const _kConcurrency = 16;

  Future<PermissionState> requestPermission() =>
      PhotoManager.requestPermissionExtend();

  /// 갤러리 **전체**를 스캔.
  ///
  /// 2단계로 동작해 체감 속도를 끌어올린다:
  ///  1) **날짜만** 먼저 모아 [onDatesReady]로 즉시 넘긴다(파일을 안 열어 빠름).
  ///     화면은 여기서 바로 날짜 기반 스토리(어느 날·이달)를 보여줄 수 있다.
  ///  2) 그다음 캐시에 없는 새 사진의 **GPS를 병렬로** 읽어(_kConcurrency 동시)
  ///     위치(여행 이름)를 채운다. [onProgress]는 이 느린 단계의 진행(done/새사진).
  ///
  /// 안드로이드 스코프 스토리지에선 GPS가 사진마다 파일을 열어 EXIF를 읽으므로
  /// 본질적으로 느리다 → UI를 막지 않도록 1단계 결과를 먼저 내보낸다.
  Future<GalleryScanResult> scan({
    void Function(int done, int total)? onProgress,
    void Function(List<StoryPhoto> datesReady)? onDatesReady,
  }) async {
    try {
      await Permission.accessMediaLocation.request();
    } catch (_) {}

    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );
    if (paths.isEmpty) {
      return const GalleryScanResult(
          photos: [], totalInGallery: 0, newlyIndexed: 0);
    }
    final all = paths.first;
    final total = await all.assetCountAsync;
    final cached = await _cache.load();

    // 1단계: 전체를 페이지로 훑어 날짜(+캐시된 위치)만 모은다 — 빠름.
    final assets = <AssetEntity>[];
    final photos = <StoryPhoto>[];
    const page = 300;
    for (var start = 0; start < total; start += page) {
      final end = (start + page) > total ? total : (start + page);
      final list = await all.getAssetListRange(start: start, end: end);
      for (final a in list) {
        assets.add(a);
        final loc = cached[a.id]; // 캐시에 있으면 위치 즉시 반영, 없으면 null
        photos.add(StoryPhoto(
          id: a.id,
          takenAt: a.createDateTime,
          lat: loc?[0],
          lng: loc?[1],
        ));
      }
    }
    // 화면이 날짜 기반 스토리를 즉시 그릴 수 있도록 스냅샷을 넘긴다.
    onDatesReady?.call(List.of(photos));

    // 2단계: 캐시에 없는 새 사진만 GPS를 병렬로 읽는다(느린 부분).
    final newOnes = assets.where((a) => !cached.containsKey(a.id)).toList();
    final freshLoc = <String, List<double>?>{};
    var done = 0;
    for (var i = 0; i < newOnes.length; i += _kConcurrency) {
      final to = math.min(i + _kConcurrency, newOnes.length);
      final chunk = newOnes.sublist(i, to);
      await Future.wait(chunk.map((a) async {
        freshLoc[a.id] = await _readLoc(a);
      }));
      done += chunk.length;
      onProgress?.call(done, newOnes.length);
    }

    // GPS를 반영한 최종 결과 + 다음 캐시.
    final next = <String, List<double>?>{}; // 이번에 본 것만 → 삭제분 정리
    final full = <StoryPhoto>[];
    for (final a in assets) {
      final loc = cached.containsKey(a.id) ? cached[a.id] : freshLoc[a.id];
      next[a.id] = loc;
      full.add(StoryPhoto(
        id: a.id,
        takenAt: a.createDateTime,
        lat: loc?[0],
        lng: loc?[1],
      ));
    }

    final newly = newOnes.length;
    if (newly > 0 || next.length != cached.length) {
      await _cache.save(next);
    }

    return GalleryScanResult(
      photos: full,
      totalInGallery: total,
      newlyIndexed: newly,
    );
  }

  /// 사진 1장의 GPS를 파일에서 읽는다(없거나 0,0이면 null).
  Future<List<double>?> _readLoc(AssetEntity a) async {
    try {
      final ll = await a.latlngAsync();
      final la = ll?.latitude;
      final lo = ll?.longitude;
      if (la != null && lo != null && (la != 0 || lo != 0)) {
        return [la, lo];
      }
    } catch (_) {}
    return null;
  }
}

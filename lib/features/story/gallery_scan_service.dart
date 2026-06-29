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
class GalleryScanService {
  const GalleryScanService();

  final _cache = const StoryIndexCache();

  Future<PermissionState> requestPermission() =>
      PhotoManager.requestPermissionExtend();

  /// 갤러리 **전체**를 스캔. [onProgress]로 진행 상황 보고.
  Future<GalleryScanResult> scan({
    void Function(int done, int total)? onProgress,
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
    final next = <String, List<double>?>{}; // 이번 스캔에서 본 것만 → 삭제분 정리
    final photos = <StoryPhoto>[];
    var newly = 0;

    const page = 100;
    for (var start = 0; start < total; start += page) {
      final end = (start + page) > total ? total : (start + page);
      final assets = await all.getAssetListRange(start: start, end: end);
      for (final a in assets) {
        List<double>? loc;
        if (cached.containsKey(a.id)) {
          loc = cached[a.id]; // 이미 읽음(없으면 null)
        } else {
          // 새 사진만 파일에서 GPS 읽기(느린 작업).
          try {
            final ll = await a.latlngAsync();
            final la = ll?.latitude;
            final lo = ll?.longitude;
            if (la != null && lo != null && (la != 0 || lo != 0)) {
              loc = [la, lo];
            }
          } catch (_) {
            loc = null;
          }
          newly++;
        }
        next[a.id] = loc;
        photos.add(StoryPhoto(
          id: a.id,
          takenAt: a.createDateTime,
          lat: loc?[0],
          lng: loc?[1],
        ));
      }
      onProgress?.call(photos.length, total);
    }

    // 새로 읽었거나 삭제분이 생겼으면 캐시 갱신.
    if (newly > 0 || next.length != cached.length) {
      await _cache.save(next);
    }

    return GalleryScanResult(
      photos: photos,
      totalInGallery: total,
      newlyIndexed: newly,
    );
  }
}

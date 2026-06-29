import 'dart:math' as math;

import 'package:photo_manager/photo_manager.dart';

import 'story_models.dart';

/// 스캔 결과 요약(미리보기 진단용).
class GalleryScanResult {
  const GalleryScanResult({
    required this.photos,
    required this.totalInGallery,
  });

  /// 엔진 입력으로 쓸 사진 메타데이터.
  final List<StoryPhoto> photos;

  /// 갤러리 전체 사진 수(스캔 상한과 무관한 실제 보유량).
  final int totalInGallery;

  int get scanned => photos.length;
  int get withLocation => photos.where((p) => p.hasLocation).length;
}

/// 폰 갤러리를 훑어 스토리 엔진 입력(날짜·GPS)을 만든다(photo_manager).
///
/// 사진 픽셀은 보지 않고 **메타데이터만** 읽는다. GPS는 기기/사진에 따라 없을 수
/// 있으며(스크린샷·카톡 사진 등) 그 경우 [StoryPhoto.lat]/lng는 null이 된다.
class GalleryScanService {
  const GalleryScanService();

  /// 사진 접근 권한 요청. 반환값으로 허용 여부를 판단한다.
  Future<PermissionState> requestPermission() =>
      PhotoManager.requestPermissionExtend();

  /// 최근 [limit]장을 스캔(반응성을 위해 상한). 최신순 album에서 범위로 가져온다.
  Future<GalleryScanResult> scanRecent({int limit = 2000}) async {
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );
    if (paths.isEmpty) {
      return const GalleryScanResult(photos: [], totalInGallery: 0);
    }
    final all = paths.first;
    final total = await all.assetCountAsync;
    final take = math.min(limit, total);

    final photos = <StoryPhoto>[];
    const page = 200;
    for (var start = 0; start < take; start += page) {
      final end = math.min(start + page, take);
      final assets = await all.getAssetListRange(start: start, end: end);
      for (final a in assets) {
        final lat = a.latitude;
        final lng = a.longitude;
        // 0,0(미설정)·null은 위치 없음으로 본다.
        final hasLoc =
            lat != null && lng != null && (lat != 0 || lng != 0);
        photos.add(StoryPhoto(
          id: a.id,
          takenAt: a.createDateTime,
          lat: hasLoc ? lat : null,
          lng: hasLoc ? lng : null,
        ));
      }
    }
    return GalleryScanResult(photos: photos, totalInGallery: total);
  }
}

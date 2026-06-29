import 'dart:math' as math;

import 'package:permission_handler/permission_handler.dart';
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
/// 사진 픽셀은 보지 않고 **메타데이터만** 읽는다. GPS는 안드로이드 보안 정책상
/// 싸구려 속성(`latitude`)으로는 0으로 가려지므로, [AssetEntity.latlngAsync]로
/// 파일에서 직접 읽는다(ACCESS_MEDIA_LOCATION 권한 필요). 그래도 없으면 null.
class GalleryScanService {
  const GalleryScanService();

  /// 사진 접근 권한 요청. 반환값으로 허용 여부를 판단한다.
  Future<PermissionState> requestPermission() =>
      PhotoManager.requestPermissionExtend();

  /// 갤러리를 스캔. [limit]장까지(최신순), [onProgress]로 진행 상황 보고.
  ///
  /// GPS는 사진마다 파일에서 읽어 정확하지만 느리므로 상한을 둔다(미리보기 검증용).
  Future<GalleryScanResult> scanRecent({
    int limit = 4000,
    void Function(int done, int total)? onProgress,
  }) async {
    // 사진 EXIF의 위치를 가리지 않고 읽기 위한 권한(있으면 GPS, 없으면 null).
    try {
      await Permission.accessMediaLocation.request();
    } catch (_) {}

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
    const page = 100;
    for (var start = 0; start < take; start += page) {
      final end = math.min(start + page, take);
      final assets = await all.getAssetListRange(start: start, end: end);
      for (final a in assets) {
        double? lat;
        double? lng;
        try {
          final ll = await a.latlngAsync();
          final la = ll?.latitude;
          final lo = ll?.longitude;
          if (la != null && lo != null && (la != 0 || lo != 0)) {
            lat = la;
            lng = lo;
          }
        } catch (_) {
          // 위치 읽기 실패는 위치 없음으로 처리.
        }
        photos.add(StoryPhoto(
          id: a.id,
          takenAt: a.createDateTime,
          lat: lat,
          lng: lng,
        ));
      }
      onProgress?.call(photos.length, take);
    }
    return GalleryScanResult(photos: photos, totalInGallery: total);
  }
}

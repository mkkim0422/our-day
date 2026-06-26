import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/utils/image_hash.dart';

/// 갤러리에서 기준 사진과 비슷한 후보 1건.
class SimilarMatch {
  const SimilarMatch(this.asset, this.similarity);
  final AssetEntity asset;
  final double similarity; // 0~1
}

/// 갤러리를 뒤져 기준 사진과 비슷한(같은 포즈/장소/구도) 사진을 찾는다.
/// 지각 해시(dHash) 기반 — 외부 서버/모델 없이 온디바이스로 동작.
class SimilarPhotoFinder {
  const SimilarPhotoFinder();

  Future<bool> ensurePermission() async {
    final ps = await PhotoManager.requestPermissionExtend();
    return ps.isAuth || ps.hasAccess;
  }

  /// 기준 해시 [refHash]와 비슷한 사진을 유사도 높은 순으로.
  /// [onProgress]로 진행률(0~1)을 알린다.
  Future<List<SimilarMatch>> findSimilar(
    int refHash, {
    int scanLimit = 500,
    int topN = 60,
    double minSimilarity = 0.6,
    void Function(double progress)? onProgress,
  }) async {
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );
    if (paths.isEmpty) return const [];
    final all = paths.first;
    final total = await all.assetCountAsync;
    final count = total < scanLimit ? total : scanLimit;
    if (count == 0) return const [];

    final assets = await all.getAssetListRange(start: 0, end: count);
    final matches = <SimilarMatch>[];
    for (var i = 0; i < assets.length; i++) {
      final a = assets[i];
      final Uint8List? thumb =
          await a.thumbnailDataWithSize(const ThumbnailSize(64, 64));
      if (thumb != null) {
        final h = ImageHash.ofBytes(thumb);
        if (h != null) {
          final sim = ImageHash.similarity(refHash, h);
          if (sim >= minSimilarity) matches.add(SimilarMatch(a, sim));
        }
      }
      if (i % 10 == 0) onProgress?.call((i + 1) / assets.length);
    }
    onProgress?.call(1);
    matches.sort((x, y) => y.similarity.compareTo(x.similarity));
    return matches.length > topN ? matches.sublist(0, topN) : matches;
  }
}

final similarPhotoFinderProvider =
    Provider<SimilarPhotoFinder>((ref) => const SimilarPhotoFinder());

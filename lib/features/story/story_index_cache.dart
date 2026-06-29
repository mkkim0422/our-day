import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 갤러리 사진의 위치(GPS) 색인을 로컬에 캐시한다(갤럭시식 1회 색인 + 증분).
///
/// GPS를 파일에서 읽는 게 유일하게 느린 작업이라, **사진별 결과를 저장**해 두고
/// 다음부터는 새 사진만 읽는다. 값: `[lat, lng]` 또는 `null`(확인했지만 위치 없음).
/// 촬영일은 AssetEntity에서 바로 얻으므로 캐시하지 않는다.
class StoryIndexCache {
  const StoryIndexCache();

  static const _fileName = 'story_index.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  /// assetId → [lat,lng] 또는 null. 없거나 손상 시 빈 맵.
  Future<Map<String, List<double>?>> load() async {
    try {
      final f = await _file();
      if (!f.existsSync()) return {};
      final raw = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return raw.map((k, v) => MapEntry(
            k,
            v == null
                ? null
                : (v as List).map((e) => (e as num).toDouble()).toList(),
          ));
    } catch (_) {
      return {};
    }
  }

  Future<void> save(Map<String, List<double>?> data) async {
    final f = await _file();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    await tmp.rename(f.path);
  }
}

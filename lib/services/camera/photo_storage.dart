import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// 저장된 사진 경로 쌍(원본 + 썸네일).
class StoredPhoto {
  const StoredPhoto({required this.originalPath, required this.thumbPath});
  final String originalPath;
  final String thumbPath;
}

/// 사진 파일 저장 서비스.
///
/// 원칙(7-1·9장): **원본은 인쇄 가능 고해상도로 보존**, 썸네일과 분리 보관.
/// 사진은 기기에만 저장(자체 서버 전송 없음).
class PhotoStorage {
  PhotoStorage({this.thumbnailWidth = 480});

  final int thumbnailWidth;
  static const _uuid = Uuid();

  /// 소스 파일(카메라 촬영물/갤러리 선택)을 앱 저장소에 복사하고 썸네일 생성.
  Future<StoredPhoto> saveFromFile(String sourcePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final capturesDir = Directory(p.join(dir.path, 'captures'));
    final thumbsDir = Directory(p.join(dir.path, 'thumbs'));
    if (!capturesDir.existsSync()) capturesDir.createSync(recursive: true);
    if (!thumbsDir.existsSync()) thumbsDir.createSync(recursive: true);

    final id = _uuid.v4();
    final originalPath = p.join(capturesDir.path, '$id.jpg');
    final thumbPath = p.join(thumbsDir.path, '$id.jpg');

    // 원본: 다운스케일 없이 그대로 복사(인쇄 품질 보존).
    await File(sourcePath).copy(originalPath);

    // 썸네일: 무거운 디코딩은 isolate에서(메인 스레드 jank 방지).
    final bytes = await File(sourcePath).readAsBytes();
    final thumbBytes = await compute(_makeThumbnail, (bytes, thumbnailWidth));
    if (thumbBytes != null) {
      await File(thumbPath).writeAsBytes(thumbBytes);
    } else {
      // 디코딩 실패 시 원본을 썸네일로 대체(깨짐 방지).
      await File(sourcePath).copy(thumbPath);
    }

    return StoredPhoto(originalPath: originalPath, thumbPath: thumbPath);
  }

  /// 원본·썸네일 파일 삭제(Capture 삭제 시 호출).
  Future<void> deleteFiles(String originalPath, String thumbPath) async {
    for (final path in [originalPath, thumbPath]) {
      final f = File(path);
      if (f.existsSync()) await f.delete();
    }
  }
}

/// isolate 진입점: 바이트 → 리사이즈 jpg 바이트.
Uint8List? _makeThumbnail((Uint8List, int) input) {
  final (bytes, width) = input;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final resized = img.copyResize(decoded, width: width);
  return img.encodeJpg(resized, quality: 85);
}

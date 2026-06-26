import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 공유 / 내보내기 서비스 (⑥장).
///
/// 9장 원칙: **공유는 사용자 주도**. 이 서비스는 사용자가 명시적으로 공유/내보내기
/// 버튼을 눌렀을 때만 호출된다. 사진·위치를 자체 서버로 보내지 않으며, OS 공유
/// 시트(`share_plus`)를 통해 사용자가 보낼 대상을 직접 고른다.
///
/// 플랫폼 의존(OS 공유 시트)은 여기에 격리한다(8장).
class ShareService {
  const ShareService();

  /// 파일들을 OS 공유 시트로 공유(단톡방·SNS 등).
  Future<ShareResult> shareFiles(List<String> paths, {String? text}) {
    // 존재하지 않는 경로는 제외(쓰기 실패/삭제 레이스 시 공유 오류 방지).
    final existing =
        paths.where((path) => File(path).existsSync()).toList();
    if (existing.isEmpty) {
      throw StateError('공유할 파일이 없습니다.');
    }
    return SharePlus.instance.share(
      ShareParams(
        files: existing.map((path) => XFile(path)).toList(),
        text: text,
      ),
    );
  }

  /// [RepaintBoundary] 위젯(예: "그때 vs 지금" 비교 뷰)을 PNG로 캡처해 저장.
  ///
  /// 사진 합성 + 한글 라벨·워터마크를 Flutter 렌더링 그대로 내보낼 수 있어,
  /// 비트맵 폰트(ASCII 한정)인 `image` 패키지 텍스트 한계를 피한다.
  Future<String> captureBoundaryToPng(
    GlobalKey boundaryKey, {
    double pixelRatio = 2.5,
  }) async {
    final context = boundaryKey.currentContext;
    if (context == null) {
      throw StateError('캡처할 위젯이 아직 렌더링되지 않았습니다.');
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw StateError('캡처할 위젯을 찾지 못했습니다.');
    }
    final image = await renderObject.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('이미지 인코딩에 실패했습니다.');
    }
    final bytes = byteData.buffer.asUint8List();

    final dir = await getApplicationDocumentsDirectory();
    final exportsDir = Directory(p.join(dir.path, 'exports'));
    if (!exportsDir.existsSync()) exportsDir.createSync(recursive: true);
    final outPath = p.join(
      exportsDir.path,
      'compare_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await File(outPath).writeAsBytes(bytes);
    return outPath;
  }
}

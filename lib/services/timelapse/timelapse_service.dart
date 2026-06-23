import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/capture/alignment_meta.dart';

/// 타임랩스 1프레임의 입력 — 원본 이미지 경로 + 정렬 보정값(4장).
@immutable
class TimelapseFrame {
  const TimelapseFrame({
    required this.imagePath,
    this.align = AlignmentMeta.identity,
  });

  final String imagePath;
  final AlignmentMeta align;
}

/// 타임랩스(슬라이드쇼 영상) 생성 서비스 (⑤·⑥장).
///
/// ## 영상 포맷 결정 — ffmpeg_kit 폐기 대응 (인수인계서 1장 주석)
/// 인수인계서가 시작점으로 제시한 `ffmpeg_kit_flutter`는 **2025년 프로젝트가
/// 공식 폐기(retired)** 되어 pub.dev에서 내려갔고 사전 빌드 바이너리 호스팅도
/// 중단됐다. 그대로 채택하면 빌드가 깨지므로 MVP는 **순수 Dart(`image` 패키지)로
/// 애니메이션 GIF** 를 생성한다.
/// - 장점: 네이티브 코드 0, 안드로이드/iOS 동일 동작, 단톡방·SNS 공유 호환,
///   유지보수 리스크 없음.
/// - 한계: 256색 팔레트(화질 손실), 대용량. 고화질 mp4가 필요해지면 플랫폼
///   네이티브 인코더(Android `MediaCodec` / iOS `AVAssetWriter`)를 이 서비스의
///   **프레임 합성 파이프라인([_composeFrame]) 뒤에 끼워** 교체한다(별도 작업).
///
/// 무거운 디코딩/리사이즈/인코딩은 모두 isolate(`compute`)에서 수행해
/// 메인 스레드 jank를 막는다.
class TimelapseService {
  TimelapseService({this.width = 600, this.frameDurationMs = 600});

  /// GIF 가로 해상도(px). 세로는 첫 프레임 비율로 계산.
  final int width;

  /// 프레임당 표시 시간(ms).
  final int frameDurationMs;

  /// [frames](시간순 오름차순)로 애니메이션 GIF를 만들고 저장 경로를 반환.
  ///
  /// 각 프레임에 [AlignmentMeta]를 적용해 흔들림을 줄인다(4장 품질 포인트).
  Future<String> buildGif(List<TimelapseFrame> frames) async {
    if (frames.length < 2) {
      throw ArgumentError('타임랩스는 최소 2장이 필요합니다. (현재 ${frames.length}장)');
    }

    final dir = await getApplicationDocumentsDirectory();
    final exportsDir = Directory(p.join(dir.path, 'exports'));
    if (!exportsDir.existsSync()) exportsDir.createSync(recursive: true);
    final outPath = p.join(exportsDir.path, 'timelapse_${frames.length}.gif');

    final specs = frames
        .map((f) => _FrameSpec(
              path: f.imagePath,
              dx: f.align.dx,
              dy: f.align.dy,
              scale: f.align.scale,
              rotationDeg: f.align.rotationDegrees,
            ))
        .toList(growable: false);

    final bytes =
        await compute(_encodeGifInIsolate, (specs, width, frameDurationMs));
    await File(outPath).writeAsBytes(bytes);
    return outPath;
  }
}

/// isolate로 넘기는 프레임 명세(모두 단순 값 → 전송 가능).
@immutable
class _FrameSpec {
  const _FrameSpec({
    required this.path,
    required this.dx,
    required this.dy,
    required this.scale,
    required this.rotationDeg,
  });

  final String path;
  final double dx;
  final double dy;
  final double scale;
  final double rotationDeg;

  bool get isIdentity => dx == 0 && dy == 0 && scale == 1.0 && rotationDeg == 0;
}

/// isolate 진입점: 프레임 명세 → 애니메이션 GIF 바이트.
Uint8List _encodeGifInIsolate((List<_FrameSpec>, int, int) input) {
  final (specs, width, frameMs) = input;

  img.Image? root;
  int canvasW = width;
  int canvasH = (width * 3 / 4).round(); // 첫 프레임 디코딩 전 임시값(4:3).

  for (final spec in specs) {
    final file = File(spec.path);
    if (!file.existsSync()) continue;
    final decoded = img.decodeImage(file.readAsBytesSync());
    if (decoded == null) continue;

    // 첫 유효 프레임의 비율로 캔버스 세로를 확정(주 방향 왜곡 방지).
    if (root == null) {
      canvasH = (width * decoded.height / decoded.width).round();
      if (canvasH.isOdd) canvasH += 1; // 인코더 호환 위해 짝수.
    }

    final frame = _composeFrame(decoded, canvasW, canvasH, spec)
      ..frameDuration = frameMs;

    if (root == null) {
      root = frame;
    } else {
      root.addFrame(frame);
    }
  }

  if (root == null) {
    throw StateError('디코딩 가능한 프레임이 없습니다.');
  }
  // repeat: 0 → 무한 반복.
  return img.encodeGif(root, repeat: 0);
}

/// 원본 1장을 캔버스(W×H)에 cover-fit 한 뒤 [AlignmentMeta]를 적용해 합성.
///
/// UI(촬영 정렬 화면)가 `BoxFit.cover` 위에 Transform(translate→rotate→scale)을
/// 적용한 것과 동일한 순서로 재현해, 타임랩스에서도 피사체가 맞물리게 한다.
img.Image _composeFrame(
  img.Image src,
  int canvasW,
  int canvasH,
  _FrameSpec spec,
) {
  final cover = _coverFit(src, canvasW, canvasH);
  if (spec.isIdentity) return cover;

  // 1) 스케일(중심 기준, 종횡비 유지).
  final scaledW = (canvasW * spec.scale).round().clamp(1, canvasW * 8);
  var layer = img.copyResize(
    cover,
    width: scaledW,
    interpolation: img.Interpolation.linear,
  );

  // 2) 회전(중심 기준). 작은 각도 가정 — 모서리는 배경(검정)으로 채워짐.
  if (spec.rotationDeg != 0) {
    layer = img.copyRotate(
      layer,
      angle: spec.rotationDeg,
      interpolation: img.Interpolation.linear,
    );
  }

  // 3) 이동(정규화 → 픽셀) + 중앙 배치 후 캔버스에 합성.
  final out = img.Image(width: canvasW, height: canvasH, numChannels: 3);
  final dstX = ((canvasW - layer.width) / 2 + spec.dx * canvasW).round();
  final dstY = ((canvasH - layer.height) / 2 + spec.dy * canvasH).round();
  img.compositeImage(out, layer, dstX: dstX, dstY: dstY);
  return out;
}

/// 캔버스를 가득 채우도록(`BoxFit.cover`) 리사이즈 후 중앙을 잘라낸다.
img.Image _coverFit(img.Image src, int canvasW, int canvasH) {
  final scale = (canvasW / src.width) > (canvasH / src.height)
      ? canvasW / src.width
      : canvasH / src.height;
  final resized = img.copyResize(
    src,
    width: (src.width * scale).round().clamp(canvasW, canvasW * 8),
    interpolation: img.Interpolation.linear,
  );
  final cropX = ((resized.width - canvasW) / 2).round().clamp(0, resized.width - 1);
  final cropY = ((resized.height - canvasH) / 2).round().clamp(0, resized.height - 1);
  return img.copyCrop(
    resized,
    x: cropX,
    y: cropY,
    width: canvasW.clamp(1, resized.width - cropX),
    height: canvasH.clamp(1, resized.height - cropY),
  );
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:our_day/features/capture/alignment_meta.dart';
import 'package:our_day/services/timelapse/timelapse_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// 문서 디렉터리를 임시 폴더로 가리키는 테스트용 path_provider 구현.
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);
  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

/// 단색 테스트 이미지를 jpg로 저장하고 경로를 반환.
String _writeImage(Directory dir, String name, int w, int h, img.Color color) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: color);
  final path = p.join(dir.path, name);
  File(path).writeAsBytesSync(img.encodeJpg(image));
  return path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('timelapse_test');
    PathProviderPlatform.instance = _FakePathProvider(temp.path);
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  group('TimelapseService.buildGif', () {
    test('프레임 수만큼의 애니메이션 GIF를 생성한다', () async {
      final a = _writeImage(temp, 'a.jpg', 200, 260, img.ColorRgb8(220, 60, 40));
      final b = _writeImage(temp, 'b.jpg', 200, 260, img.ColorRgb8(40, 160, 90));
      final c = _writeImage(temp, 'c.jpg', 200, 260, img.ColorRgb8(40, 90, 200));

      final service = TimelapseService(width: 120, frameDurationMs: 400);
      final outPath = await service.buildGif([
        TimelapseFrame(imagePath: a),
        // 정렬 보정이 적용된 프레임도 깨지지 않아야 한다.
        TimelapseFrame(
          imagePath: b,
          align: const AlignmentMeta(dx: 0.05, dy: -0.03, scale: 1.1, rotation: 0.04),
        ),
        TimelapseFrame(imagePath: c),
      ]);

      final file = File(outPath);
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(0));
      expect(p.extension(outPath), '.gif');

      final decoded = img.decodeGif(file.readAsBytesSync());
      expect(decoded, isNotNull);
      expect(decoded!.numFrames, 3);
      // 캔버스 가로는 요청한 width로 고정.
      expect(decoded.width, 120);
    });

    test('첫 프레임 비율로 캔버스 세로가 정해진다(왜곡 방지)', () async {
      // 가로 100 × 세로 200(2:1 세로형) → width 100이면 세로 200(±짝수 보정).
      final a = _writeImage(temp, 'a.jpg', 100, 200, img.ColorRgb8(10, 10, 10));
      final b = _writeImage(temp, 'b.jpg', 100, 200, img.ColorRgb8(250, 250, 250));

      final service = TimelapseService(width: 100);
      final out = await service.buildGif(
        [TimelapseFrame(imagePath: a), TimelapseFrame(imagePath: b)],
      );

      final decoded = img.decodeGif(File(out).readAsBytesSync())!;
      expect(decoded.width, 100);
      expect(decoded.height, anyOf(200, 201, 202)); // 비율 유지 + 짝수 보정 여유.
    });

    test('2장 미만이면 ArgumentError', () async {
      final a = _writeImage(temp, 'a.jpg', 50, 50, img.ColorRgb8(0, 0, 0));
      final service = TimelapseService();
      expect(
        () => service.buildGif([TimelapseFrame(imagePath: a)]),
        throwsArgumentError,
      );
    });
  });
}

import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

/// 카메라 제어 서비스 (8장: 플랫폼 의존 코드 격리).
///
/// 화면은 이 서비스를 통해 카메라 권한·프리뷰·촬영을 다룬다.
class CameraService {
  CameraController? _controller;

  CameraController? get controller => _controller;
  bool get isReady => _controller?.value.isInitialized ?? false;

  /// 카메라 권한 요청(필요한 시점에 단계적 요청 — 1·3장).
  Future<bool> requestPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// 후면 카메라로 초기화. 인쇄 품질 위해 고해상도부터 시도하되, 기기가 지원하는
  /// surface 조합을 못 찾으면(일부 삼성 등 CameraX 3-스트림 한계) 단계적으로 낮춘다.
  Future<void> initialize() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw CameraException('no_camera', '사용 가능한 카메라가 없습니다.');
    }
    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    // 고화질 → 호환 순으로 폴백.
    const presets = [
      ResolutionPreset.veryHigh,
      ResolutionPreset.high,
      ResolutionPreset.medium,
    ];
    CameraException? lastError;
    for (final preset in presets) {
      final controller = CameraController(
        back,
        preset,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      try {
        await controller.initialize();
        _controller = controller;
        return;
      } on CameraException catch (e) {
        lastError = e;
        await controller.dispose();
      }
    }
    throw lastError ??
        CameraException('init_failed', '카메라를 초기화할 수 없습니다.');
  }

  /// 촬영 → 임시 파일(XFile). 저장은 PhotoStorage가 담당.
  Future<XFile> takePicture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      throw CameraException('not_ready', '카메라가 준비되지 않았습니다.');
    }
    return c.takePicture();
  }

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}

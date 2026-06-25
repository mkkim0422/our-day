import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

/// 카메라 제어 서비스 (8장: 플랫폼 의존 코드 격리).
///
/// 화면은 이 서비스를 통해 권한·프리뷰·촬영·줌·포커스·플래시·전후면 전환을 다룬다.
class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  CameraLensDirection _lens = CameraLensDirection.back;

  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _zoom = 1.0;

  CameraController? get controller => _controller;
  bool get isReady => _controller?.value.isInitialized ?? false;
  CameraLensDirection get lensDirection => _lens;
  double get minZoom => _minZoom;
  double get maxZoom => _maxZoom;
  double get zoom => _zoom;
  bool get hasFrontAndBack =>
      _cameras.any((c) => c.lensDirection == CameraLensDirection.back) &&
      _cameras.any((c) => c.lensDirection == CameraLensDirection.front);

  /// 카메라 권한 요청(필요한 시점에 단계적 요청 — 1·3장).
  Future<bool> requestPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// 지정 렌즈로 초기화. 고화질부터 시도하되 surface 조합 실패 시 단계적으로 낮춘다
  /// (일부 삼성 등 CameraX 3-스트림 한계 대응).
  Future<void> initialize({CameraLensDirection? lens}) async {
    if (_cameras.isEmpty) _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      throw CameraException('no_camera', '사용 가능한 카메라가 없습니다.');
    }
    _lens = lens ?? _lens;
    final cam = _cameras.firstWhere(
      (c) => c.lensDirection == _lens,
      orElse: () => _cameras.first,
    );

    const presets = [
      ResolutionPreset.veryHigh,
      ResolutionPreset.high,
      ResolutionPreset.medium,
    ];
    CameraException? lastError;
    for (final preset in presets) {
      final controller = CameraController(
        cam,
        preset,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      try {
        await controller.initialize();
        _controller = controller;
        _minZoom = await controller.getMinZoomLevel();
        _maxZoom = await controller.getMaxZoomLevel();
        _zoom = _minZoom;
        return;
      } on CameraException catch (e) {
        lastError = e;
        await controller.dispose();
      }
    }
    throw lastError ??
        CameraException('init_failed', '카메라를 초기화할 수 없습니다.');
  }

  /// 전/후면 전환(다음 초기화 위해 현재 컨트롤러 해제).
  Future<void> switchLens() async {
    final next = _lens == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    await dispose();
    await initialize(lens: next);
  }

  /// 핀치 줌(min~max로 클램프).
  Future<void> setZoom(double value) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    _zoom = value.clamp(_minZoom, _maxZoom);
    await c.setZoomLevel(_zoom);
  }

  /// 탭한 지점(정규화 0~1)으로 초점·노출 맞추기.
  Future<void> focusAt(Offset normalized) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      await c.setFocusPoint(normalized);
      await c.setExposurePoint(normalized);
    } on CameraException {
      // 일부 기기 미지원 — 무시.
    }
  }

  Future<void> setFlashMode(FlashMode mode) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      await c.setFlashMode(mode);
    } on CameraException {
      // 미지원 무시.
    }
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

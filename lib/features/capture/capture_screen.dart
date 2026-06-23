import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/db/app_database.dart';
import '../../services/camera/camera_service.dart';
import 'alignment_adjuster_screen.dart';
import 'widgets/guide_grid.dart';

/// ④ 촬영 화면 — ★킬러 기능 오버레이 정렬 카메라 (4장).
///
/// 직전(또는 기준/장소) 사진을 뷰파인더 위에 반투명 합성하고, 투명도 슬라이더와
/// 가이드 프레임으로 같은 포즈를 유도한다. 촬영 후 정렬 조정 화면으로 이동.
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({
    super.key,
    required this.project,
    this.referenceCapture,
    this.placeId,
  });

  final Project project;

  /// 오버레이 기준 사진. null이면 첫 촬영(가이드 프레임만).
  /// 위치 알림 진입 시 그 장소의 예전 Capture가 주입된다(4·5장).
  final Capture? referenceCapture;
  final String? placeId;

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen>
    with WidgetsBindingObserver {
  final _camera = CameraService();
  final _picker = ImagePicker();

  bool _initializing = true;
  bool _permissionDenied = false;
  String? _error;
  double _overlayOpacity = 0.45; // 기본 40~50% (4장)
  bool _showOverlay = true;
  bool _busy = false;

  String? get _referencePath => widget.referenceCapture?.filePath;
  bool get _hasReference => _referencePath != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setup();
  }

  Future<void> _setup() async {
    final granted = await _camera.requestPermission();
    if (!mounted) return;
    if (!granted) {
      setState(() {
        _initializing = false;
        _permissionDenied = true;
      });
      return;
    }
    try {
      await _camera.initialize();
      // 초기화 도중 화면이 사라졌으면 새로 만든 컨트롤러를 즉시 해제(하드웨어 누수 방지).
      if (!mounted) {
        await _camera.dispose();
        return;
      }
    } on CameraException catch (e) {
      if (mounted) setState(() => _error = e.description ?? e.code);
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  /// OS가 백그라운드에서 카메라를 강제 회수하므로(특히 Android), 화면이 가려지면
  /// 컨트롤러를 해제하고 복귀 시 재초기화한다(검은 프리뷰·예외 방지).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_permissionDenied || _error != null) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _camera.dispose();
      if (mounted) setState(() {}); // isReady=false → 프리뷰 숨김.
    } else if (state == AppLifecycleState.resumed && !_camera.isReady) {
      setState(() => _initializing = true);
      _setup();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera.dispose();
    super.dispose();
  }

  Future<void> _shutter() async {
    if (_busy || !_camera.isReady) return;
    setState(() => _busy = true);
    try {
      final shot = await _camera.takePicture();
      await _openAdjuster(shot.path);
    } on CameraException catch (e) {
      _snack('촬영 실패: ${e.description ?? e.code}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 입력경로 2: 갤러리에서 불러오기(②-1). 동일하게 정렬 조정 후 저장.
  Future<void> _pickFromGallery() async {
    if (_busy) return;
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    await _openAdjuster(picked.path);
  }

  Future<void> _openAdjuster(String imagePath) async {
    final result = await Navigator.of(context).push<Capture>(
      MaterialPageRoute(
        builder: (_) => AlignmentAdjusterScreen(
          project: widget.project,
          capturedImagePath: imagePath,
          capturedAt: DateTime.now(),
          referenceImagePath: _referencePath,
          placeId: widget.placeId,
        ),
      ),
    );
    // 저장 완료 시 촬영 화면도 닫아 홈으로 복귀.
    if (result != null && mounted) Navigator.of(context).pop(result);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_initializing) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }
    if (_permissionDenied) return _permissionView();
    if (_error != null) {
      return Center(
        child: Text('카메라 오류: $_error',
            style: const TextStyle(color: Colors.white)),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        // 카메라 실시간 뷰파인더.
        if (_camera.isReady)
          Center(child: CameraPreview(_camera.controller!)),
        // 직전/기준 사진 반투명 오버레이.
        if (_hasReference && _showOverlay)
          IgnorePointer(
            child: Opacity(
              opacity: _overlayOpacity,
              child: Image.file(
                File(_referencePath!),
                fit: BoxFit.cover,
                // 기준 원본이 없으면(예: 복원 후) 깨진 오버레이 대신 숨김.
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        const GuideGrid(),
        _topBar(),
        _bottomControls(),
      ],
    );
  }

  Widget _permissionView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography,
                color: Colors.white70, size: 56),
            const SizedBox(height: 16),
            const Text(
              '카메라 권한이 필요합니다.\n같은 포즈로 사진을 찍으려면 카메라 접근을 허용해 주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                setState(() {
                  _initializing = true;
                  _permissionDenied = false;
                });
                _setup();
              },
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Positioned(
      top: 8,
      left: 4,
      right: 4,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              widget.project.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          if (_hasReference)
            IconButton(
              tooltip: '오버레이 켜기/끄기',
              icon: Icon(
                _showOverlay ? Icons.layers : Icons.layers_clear,
                color: Colors.white,
              ),
              onPressed: () => setState(() => _showOverlay = !_showOverlay),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _bottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_hasReference && _showOverlay)
              Row(
                children: [
                  const Icon(Icons.opacity, color: Colors.white70, size: 20),
                  Expanded(
                    child: Slider(
                      value: _overlayOpacity,
                      onChanged: (v) =>
                          setState(() => _overlayOpacity = v),
                    ),
                  ),
                ],
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  iconSize: 32,
                  icon: const Icon(Icons.photo_library_outlined,
                      color: Colors.white),
                  tooltip: '갤러리에서 불러오기',
                  onPressed: _busy ? null : _pickFromGallery,
                ),
                _ShutterButton(busy: _busy, onTap: _shutter),
                const SizedBox(width: 48), // 좌우 균형(향후 전/후면 토글 자리)
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.busy, required this.onTap});
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '촬영',
      child: GestureDetector(
        onTap: busy ? null : onTap,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.2),
            border: Border.all(color: Colors.white, width: 4),
          ),
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.circle, color: Colors.white, size: 52),
        ),
      ),
    );
  }
}

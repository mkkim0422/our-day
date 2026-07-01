import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../services/camera/camera_service.dart';
import '../../services/providers.dart';
import '../home/home_providers.dart';
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

  bool _initializing = true;
  bool _permissionDenied = false;
  String? _error;
  double _overlayOpacity = 0.45; // 기본 40~50% (4장)
  bool _showOverlay = true;
  bool _busy = false;

  /// 겹쳐 볼 기준 사진. 기본은 가장 최근 컷(widget.referenceCapture)이고,
  /// 아래 사진 버튼으로 '내가 찍은 사진들' 중 다른 컷으로 바꿀 수 있다.
  Capture? _reference;

  // 기본 카메라 기능: 줌·탭포커스·플래시·전후면.
  double _baseZoom = 1.0;
  FlashMode _flash = FlashMode.off;
  Offset? _focusPoint; // 탭 포커스 표시(잠깐)
  Timer? _focusTimer;
  bool _shutterFlash = false; // 촬영 순간 화면 플래시

  // 셀프 타이머: 0(끄기) → 3 → 5 → 10초 순환. 같은 포즈로 직접 들어가 찍을 때 유용.
  static const _timerOptions = [0, 3, 5, 10];
  int _timerSec = 0;
  int? _countdown; // 카운트다운 중 남은 초(null이면 비활성)
  Timer? _countdownTimer;

  String? get _referencePath => _reference?.filePath;
  bool get _hasReference => _referencePath != null;

  @override
  void initState() {
    super.initState();
    _reference = widget.referenceCapture;
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
      await _camera.setFlashMode(_flash);
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
      _cancelCountdown(); // 화면 가려지면 카운트다운 중단.
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
    _countdownTimer?.cancel();
    _focusTimer?.cancel();
    _camera.dispose();
    super.dispose();
  }

  /// 타이머 순환(0→3→5→10→0). 카운트다운 중엔 바꾸지 않는다.
  void _cycleTimer() {
    if (_countdown != null) return;
    final next = (_timerOptions.indexOf(_timerSec) + 1) % _timerOptions.length;
    setState(() => _timerSec = _timerOptions[next]);
  }

  /// 셔터 탭. 카운트다운 중이면 취소, 타이머가 켜져 있으면 카운트다운 시작,
  /// 아니면 바로 촬영.
  void _onShutterTap() {
    if (_countdown != null) {
      _cancelCountdown();
      return;
    }
    if (_busy || !_camera.isReady) return;
    if (_timerSec == 0) {
      _capture();
    } else {
      _startCountdown();
    }
  }

  void _startCountdown() {
    setState(() => _countdown = _timerSec);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final next = (_countdown ?? 1) - 1;
      if (next <= 0) {
        t.cancel();
        setState(() => _countdown = null);
        _capture();
      } else {
        setState(() => _countdown = next);
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (_countdown != null && mounted) setState(() => _countdown = null);
  }

  // ── 기본 카메라 기능 ──

  void _onScaleStart(ScaleStartDetails d) => _baseZoom = _camera.zoom;

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount < 2) return; // 한 손가락은 무시(탭 포커스용).
    _camera.setZoom(_baseZoom * d.scale);
    setState(() {}); // 줌 표시 갱신.
  }

  void _onTapFocus(TapUpDetails d) {
    final size = context.size;
    if (size == null) return;
    final local = d.localPosition;
    _camera.focusAt(Offset(
      (local.dx / size.width).clamp(0.0, 1.0),
      (local.dy / size.height).clamp(0.0, 1.0),
    ));
    setState(() => _focusPoint = local);
    _focusTimer?.cancel();
    _focusTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _focusPoint = null);
    });
  }

  void _cycleFlash() {
    const modes = [FlashMode.off, FlashMode.auto, FlashMode.always];
    final next = modes[(modes.indexOf(_flash) + 1) % modes.length];
    setState(() => _flash = next);
    _camera.setFlashMode(next);
  }

  Future<void> _switchLens() async {
    if (_busy || !_camera.hasFrontAndBack) return;
    setState(() => _busy = true);
    try {
      await _camera.switchLens();
      await _camera.setFlashMode(_flash);
    } on CameraException catch (e) {
      _snack('카메라 전환 실패: ${e.description ?? e.code}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _capture() async {
    if (_busy || !_camera.isReady) return;
    HapticFeedback.mediumImpact();
    // 셔터 플래시(촬영됐다는 즉각 피드백).
    setState(() {
      _busy = true;
      _shutterFlash = true;
    });
    Future.delayed(const Duration(milliseconds: 140), () {
      if (mounted) setState(() => _shutterFlash = false);
    });
    try {
      final shot = await _camera.takePicture();
      await _openAdjuster(shot.path);
    } on CameraException catch (e) {
      _snack('촬영 실패: ${e.description ?? e.code}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 겹쳐 볼 기준 사진을 '내가 찍은 사진들'(이 프로젝트 기록)에서 고른다.
  /// 폰 갤러리 전체가 아니라 앱에 쌓인 컷 중에서 골라 같은 포즈로 이어 찍게.
  /// (예전 사진을 새로 채우려면 앨범 ⋮ '예전 사진 채우기'를 쓴다.)
  Future<void> _pickReference() async {
    if (_busy) return;
    final caps =
        ref.read(capturesProvider(widget.project.id)).value ?? const <Capture>[];
    if (caps.isEmpty) {
      _snack('아직 겹쳐 볼 사진이 없어요.');
      return;
    }
    final picked = await showModalBottomSheet<Capture>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) =>
          _ReferencePicker(captures: caps, selectedId: _reference?.id),
    );
    if (picked != null && mounted) {
      setState(() {
        _reference = picked;
        _showOverlay = true;
      });
    }
  }

  /// 카메라 촬영은 capturedAt=now(방금 찍음), 갤러리 불러오기는 EXIF 촬영일을 넘긴다.
  Future<void> _openAdjuster(String imagePath, {DateTime? capturedAt}) async {
    final result = await Navigator.of(context).push<Capture>(
      MaterialPageRoute(
        builder: (_) => AlignmentAdjusterScreen(
          project: widget.project,
          capturedImagePath: imagePath,
          capturedAt: capturedAt ?? DateTime.now(),
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
        // 카메라 실시간 뷰파인더 — 화면을 cover로 꽉 채워 오버레이/저장본과 크롭 일치.
        // 핀치=줌, 탭=초점.
        if (_camera.isReady)
          Positioned.fill(
            child: GestureDetector(
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              onTapUp: _onTapFocus,
              child: _coverPreview(),
            ),
          ),
        // 직전/기준 사진 반투명 오버레이(프리뷰와 동일하게 cover → 정렬 일치).
        if (_hasReference && _showOverlay)
          IgnorePointer(
            child: Opacity(
              opacity: _overlayOpacity,
              child: Image.file(
                File(_referencePath!),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        const IgnorePointer(child: GuideGrid()),
        // 셔터 플래시.
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _shutterFlash ? 0.85 : 0,
            duration: const Duration(milliseconds: 120),
            child: Container(color: Colors.white),
          ),
        ),
        if (_focusPoint != null) _focusIndicator(),
        if (_camera.isReady && _camera.zoom > _camera.minZoom + 0.05)
          _zoomPill(),
        if (_countdown != null) _countdownOverlay(),
        _topBar(),
        _bottomControls(),
        // 오버레이(반투명 겹침)가 처음 뜨는 순간 1회성 코치 — 오류 오해 방지.
        if (_hasReference && _camera.isReady && _countdown == null && !_coachSeen)
          _OverlayCoach(
            onDismiss: () =>
                ref.read(appSettingsProvider.notifier).markCaptureCoachSeen(),
          ),
      ],
    );
  }

  /// 설정 로딩 중(null)엔 깜빡임 방지를 위해 '봤음'으로 간주(표시 안 함).
  bool get _coachSeen =>
      ref.watch(appSettingsProvider).value?.captureCoachSeen ?? true;

  /// 프리뷰를 화면에 cover로 채운다(레터박스 제거 → 오버레이/저장본과 크롭 일치).
  Widget _coverPreview() {
    final c = _camera.controller!;
    final media = MediaQuery.of(context).size;
    var scale = c.value.aspectRatio * (media.width / media.height);
    if (scale < 1) scale = 1 / scale;
    return ClipRect(
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.center,
        child: Center(child: CameraPreview(c)),
      ),
    );
  }

  Widget _focusIndicator() {
    return Positioned(
      left: _focusPoint!.dx - 28,
      top: _focusPoint!.dy - 28,
      child: IgnorePointer(
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _zoomPill() {
    return Positioned(
      bottom: 150,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('${_camera.zoom.toStringAsFixed(1)}x',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }

  /// 카운트다운 오버레이 — 큰 숫자 + "탭하면 취소". 숫자 영역 탭으로 취소 가능
  /// (상단 닫기/하단 컨트롤은 위에 렌더되어 그대로 동작).
  Widget _countdownOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: _cancelCountdown,
        child: Container(
          color: Colors.black.withValues(alpha: 0.35),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$_countdown',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 104,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              const SizedBox(height: 12),
              const Text('탭하면 취소',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
        ),
      ),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          // 플래시.
          IconButton(
            tooltip: '플래시',
            icon: Icon(_flashIcon(), color: Colors.white),
            onPressed: _busy ? null : _cycleFlash,
          ),
          // 전/후면 전환.
          if (_camera.hasFrontAndBack)
            IconButton(
              tooltip: '카메라 전환',
              icon: const Icon(Icons.cameraswitch_outlined, color: Colors.white),
              onPressed: _busy ? null : _switchLens,
            ),
          // 오버레이 켜기/끄기.
          if (_hasReference)
            IconButton(
              tooltip: '오버레이 켜기/끄기',
              icon: Icon(
                _showOverlay ? Icons.layers : Icons.layers_clear,
                color: Colors.white,
              ),
              onPressed: () => setState(() => _showOverlay = !_showOverlay),
            ),
        ],
      ),
    );
  }

  IconData _flashIcon() => switch (_flash) {
        FlashMode.always => Icons.flash_on,
        FlashMode.auto => Icons.flash_auto,
        _ => Icons.flash_off,
      };

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
                  const Icon(Icons.layers, color: Colors.white70, size: 18),
                  const SizedBox(width: 4),
                  const Text('겹쳐 보기',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: _overlayOpacity,
                      onChanged: (v) => setState(() => _overlayOpacity = v),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text('${(_overlayOpacity * 100).round()}%',
                        textAlign: TextAlign.right,
                        style:
                            const TextStyle(color: Colors.white70, fontSize: 12)),
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
                  tooltip: '겹쳐 볼 사진 고르기',
                  onPressed:
                      (_busy || _countdown != null) ? null : _pickReference,
                ),
                _ShutterButton(busy: _busy, onTap: _onShutterTap),
                _TimerButton(
                  seconds: _timerSec,
                  enabled: _countdown == null,
                  onTap: _cycleTimer,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 겹쳐 볼 기준 사진 고르기 — 폰 갤러리 전체가 아니라 '이 프로젝트에서 내가
/// 찍은 컷'만 그리드로 보여주고, 고르면 그 사진을 반투명 오버레이 기준으로 쓴다.
class _ReferencePicker extends StatelessWidget {
  const _ReferencePicker({required this.captures, this.selectedId});

  final List<Capture> captures;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Icon(Icons.layers, size: 20, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text('겹쳐 볼 사진 고르기',
                      style: text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            Flexible(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: captures.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.78,
                ),
                itemBuilder: (context, i) {
                  final c = captures[i];
                  final selected = c.id == selectedId;
                  final img = File(c.thumbPath);
                  return InkWell(
                    onTap: () => Navigator.of(context).pop(c),
                    borderRadius: BorderRadius.circular(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: selected
                                  ? Border.all(color: scheme.primary, width: 3)
                                  : null,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: img.existsSync()
                                  ? Image.file(img, fit: BoxFit.cover)
                                  : ColoredBox(
                                      color: scheme.surfaceContainerHighest),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(c.periodLabel,
                            style: text.labelSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 셀프 타이머 토글 버튼(셔터 오른쪽). 끄기/3/5/10초를 아이콘+라벨로 표시.
class _TimerButton extends StatelessWidget {
  const _TimerButton({
    required this.seconds,
    required this.enabled,
    required this.onTap,
  });

  final int seconds;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final on = seconds > 0;
    final color = Colors.white.withValues(alpha: enabled ? 1 : 0.4);
    return Tooltip(
      message: '셀프 타이머',
      child: SizedBox(
        width: 48,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(on ? Icons.timer : Icons.timer_off_outlined,
                    color: color, size: 28),
                if (on)
                  Text(
                    '${seconds}s',
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
              ],
            ),
          ),
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

/// 오버레이(반투명 겹침) 첫 등장 시 1회성 코치 — "오류 아님"을 시각적으로 설명.
///
/// 딤 스크림 위에 부드럽게 떠오르는 카드 + 겹친 인물 데모로 기능을 직관적으로 전달.
class _OverlayCoach extends StatefulWidget {
  const _OverlayCoach({required this.onDismiss});
  final VoidCallback onDismiss;

  @override
  State<_OverlayCoach> createState() => _OverlayCoachState();
}

class _OverlayCoachState extends State<_OverlayCoach>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 440))
    ..forward();
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.06),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Positioned.fill(
      child: FadeTransition(
        opacity: _fade,
        child: Stack(
          children: [
            // 딤 스크림 — 탭하면 닫힘.
            GestureDetector(
              onTap: widget.onDismiss,
              child: Container(color: Colors.black.withValues(alpha: 0.66)),
            ),
            Center(
              child: SlideTransition(
                position: _slide,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 28),
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _GhostDemo(scheme: scheme, text: text),
                      const SizedBox(height: 20),
                      Text('같은 포즈로 겹쳐 찍어요',
                          style: text.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface)),
                      const SizedBox(height: 10),
                      Text(
                        '직전 사진이 반투명으로 비쳐 보여요.\n그 위에 같은 포즈를 맞추면, 시간이 흘러도\n자연스럽게 이어지는 타임랩스가 완성돼요.',
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant, height: 1.45),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.tune_rounded,
                                size: 16, color: scheme.primary),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text('아래 슬라이더로 투명도를 조절할 수 있어요',
                                  style: text.labelMedium?.copyWith(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: widget.onDismiss,
                        child: const Text('좋아요, 찍어볼게요'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 코치 카드의 핵심 비주얼 — 뷰파인더 안에 '이전 컷(반투명)'과 '지금'이 겹친 모습.
class _GhostDemo extends StatelessWidget {
  const _GhostDemo({required this.scheme, required this.text});
  final ColorScheme scheme;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                scheme.primaryContainer.withValues(alpha: 0.6),
                scheme.surfaceContainerHighest,
              ],
            ),
          ),
          child: Stack(
            children: [
              // 가이드 그리드(3분할) — 같은 구도 맞춤을 암시.
              Positioned.fill(
                child: CustomPaint(painter: _GridPainter(scheme.outlineVariant)),
              ),
              // 겹친 인물: 이전(반투명·살짝 왼쪽) + 지금(또렷).
              Center(
                child: SizedBox(
                  height: 124,
                  width: 170,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Transform.translate(
                        offset: const Offset(-18, 0),
                        child: Icon(Icons.person,
                            size: 108,
                            color: scheme.primary.withValues(alpha: 0.26)),
                      ),
                      Icon(Icons.person, size: 108, color: scheme.primary),
                    ],
                  ),
                ),
              ),
              Positioned(left: 10, top: 10, child: _tag('이전 컷 · 반투명', faint: true)),
              Positioned(right: 10, top: 10, child: _tag('지금', faint: false)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String label, {required bool faint}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: faint ? scheme.surface.withValues(alpha: 0.78) : scheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: text.labelSmall?.copyWith(
            color: faint ? scheme.onSurfaceVariant : scheme.onPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 10,
          )),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final dx = size.width * i / 3;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), p);
      final dy = size.height * i / 3;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.color != color;
}

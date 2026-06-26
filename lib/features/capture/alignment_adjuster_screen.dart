import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/repositories/providers.dart';
import '../../services/providers.dart';
import 'alignment_meta.dart';
import 'widgets/guide_grid.dart';

/// 촬영 직후 미세 조정 화면 (4장 4번).
///
/// 새 촬영물을 기준(직전) 사진에 맞춰 **이동·스케일·회전** 조정하고,
/// 보정값을 alignment_meta로 저장한다. 원본 이미지는 변형하지 않고
/// 고해상도 그대로 저장(인쇄 품질 보존, 7-1장).
class AlignmentAdjusterScreen extends ConsumerStatefulWidget {
  const AlignmentAdjusterScreen({
    super.key,
    required this.project,
    required this.capturedImagePath,
    required this.capturedAt,
    this.referenceImagePath,
    this.placeId,
  });

  final Project project;
  final String capturedImagePath;
  final DateTime capturedAt;

  /// 기준 사진 경로(직전/장소 기반). 없으면 첫 촬영 → 조정 생략.
  final String? referenceImagePath;
  final String? placeId;

  @override
  ConsumerState<AlignmentAdjusterScreen> createState() =>
      _AlignmentAdjusterScreenState();
}

class _AlignmentAdjusterScreenState
    extends ConsumerState<AlignmentAdjusterScreen> {
  Offset _offset = Offset.zero;
  double _scale = 1.0;
  double _rotation = 0.0;
  double _refOpacity = 0.5;
  bool _saving = false;
  Size _viewSize = Size.zero;

  // 제스처 시작 시점 스냅샷.
  Offset _startFocal = Offset.zero;
  Offset _baseOffset = Offset.zero;
  double _baseScale = 1.0;
  double _baseRotation = 0.0;

  bool get _hasReference => widget.referenceImagePath != null;

  void _onScaleStart(ScaleStartDetails d) {
    _startFocal = d.focalPoint;
    _baseOffset = _offset;
    _baseScale = _scale;
    _baseRotation = _rotation;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      _scale = (_baseScale * d.scale).clamp(0.3, 4.0);
      _rotation = _baseRotation + d.rotation;
      _offset = _baseOffset + (d.focalPoint - _startFocal);
    });
  }

  void _reset() {
    setState(() {
      _offset = Offset.zero;
      _scale = 1.0;
      _rotation = 0.0;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final storage = ref.read(photoStorageProvider);
      final captures = ref.read(captureRepositoryProvider);

      final stored = await storage.saveFromFile(widget.capturedImagePath);

      final meta = _hasReference
          ? AlignmentMeta(
              dx: _viewSize.width == 0 ? 0 : _offset.dx / _viewSize.width,
              dy: _viewSize.height == 0 ? 0 : _offset.dy / _viewSize.height,
              scale: _scale,
              rotation: _rotation,
            )
          : AlignmentMeta.identity;

      // 위치 태깅(5장): opt-in이면 현재 좌표로 Place를 만들거나 재사용해 연결한다.
      // (회상 알림으로 진입한 경우엔 이미 placeId가 주어짐.)
      final placeId = widget.placeId ?? await _resolvePlaceId();

      final capture = await captures.create(
        project: widget.project,
        filePath: stored.originalPath,
        thumbPath: stored.thumbPath,
        capturedAt: widget.capturedAt,
        alignmentMeta: meta.isIdentity ? null : meta.toMap(),
        placeId: placeId,
      );

      // 저장 후 알림 재예약: 다음 기간 리마인더 갱신 + 이 사진의 기념일(회상) 추가.
      final all = await captures.listByProject(widget.project.id);
      final birthday =
          ref.read(appSettingsProvider).value?.projectBirthdays[widget.project.id];
      await ref
          .read(notificationServiceProvider)
          .scheduleForProject(widget.project, all, birthday: birthday);

      HapticFeedback.heavyImpact(); // 저장 완료 — 손맛 피드백.
      if (mounted) Navigator.of(context).pop(capture);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// opt-in 시 현재 위치로 Place를 찾거나(반경 내 재사용) 새로 만들어 id 반환.
  /// 위치 회상이 꺼져 있거나 위치를 못 얻으면 null(촬영은 정상 저장).
  Future<String?> _resolvePlaceId() async {
    final settings = ref.read(appSettingsProvider).value;
    if (settings == null || !settings.locationRecallEnabled) return null;

    final point = await ref.read(locationServiceProvider).current();
    if (point == null) return null;

    final placeRepo = ref.read(placeRepositoryProvider);
    final existing = await placeRepo.findNear(
        widget.project.id, point.latitude, point.longitude);
    if (existing != null) {
      await placeRepo.incrementCaptureCount(existing.id);
      // 촬영 횟수가 바뀌었으니 지오펜스 우선순위(상위 N개만 켜기) 재정렬.
      await placeRepo.enforceGeofenceLimit(widget.project.id);
      return existing.id;
    }
    final created = await placeRepo.create(
      projectId: widget.project.id,
      label: '촬영 장소 '
          '(${point.latitude.toStringAsFixed(3)}, '
          '${point.longitude.toStringAsFixed(3)})',
      latitude: point.latitude,
      longitude: point.longitude,
    );
    // 새 장소 포함해 capture_count 상위 N개만 지오펜스 활성(플랫폼 한도 대응, 5장).
    await placeRepo.enforceGeofenceLimit(widget.project.id);
    return created.id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_hasReference ? '같은 포즈로 맞추기' : '사진 확인'),
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _viewSize = Size(constraints.maxWidth, constraints.maxHeight);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // 조정 대상: 새 촬영물(제스처로 이동/스케일/회전).
                    GestureDetector(
                      onScaleStart: _hasReference ? _onScaleStart : null,
                      onScaleUpdate: _hasReference ? _onScaleUpdate : null,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..translateByDouble(
                              _offset.dx, _offset.dy, 0, 1)
                          ..rotateZ(_rotation)
                          ..scaleByDouble(_scale, _scale, 1, 1),
                        child: Image.file(
                          File(widget.capturedImagePath),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    // 기준 사진 고스트(고정, 반투명) — 정렬 타깃.
                    if (_hasReference)
                      IgnorePointer(
                        child: Opacity(
                          opacity: _refOpacity,
                          child: Image.file(
                            File(widget.referenceImagePath!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    const GuideGrid(),
                  ],
                );
              },
            ),
          ),
          _controls(),
        ],
      ),
    );
  }

  Widget _controls() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_hasReference) ...[
            Row(
              children: [
                const Icon(Icons.opacity, color: Colors.white70, size: 20),
                Expanded(
                  child: Slider(
                    value: _refOpacity,
                    onChanged: (v) => setState(() => _refOpacity = v),
                  ),
                ),
                TextButton(
                  onPressed: _reset,
                  child: const Text('초기화'),
                ),
              ],
            ),
            const Text(
              '새 사진을 움직여 흐린 기준 사진에 맞추세요 (두 손가락: 확대·회전)',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_saving ? '저장 중…' : '저장'),
            ),
          ),
        ],
      ),
    );
  }
}

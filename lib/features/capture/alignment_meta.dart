import 'dart:math' as math;

/// 촬영 정렬 보정값 (4장 — alignment_meta).
///
/// 새 촬영을 기준(직전) 사진에 맞추기 위해 적용한 변환을 기록한다.
/// 타임랩스 생성 시 이 값을 반영해 흔들림을 줄인다(4장 품질 포인트).
///
/// - [dx]/[dy]: 위젯 크기 대비 **정규화된 이동**(해상도 독립).
/// - [scale]: 배율(1.0 = 원본).
/// - [rotation]: 회전(라디안).
class AlignmentMeta {
  const AlignmentMeta({
    this.dx = 0,
    this.dy = 0,
    this.scale = 1.0,
    this.rotation = 0,
  });

  final double dx;
  final double dy;
  final double scale;
  final double rotation;

  static const identity = AlignmentMeta();

  bool get isIdentity =>
      dx == 0 && dy == 0 && scale == 1.0 && rotation == 0;

  AlignmentMeta copyWith({
    double? dx,
    double? dy,
    double? scale,
    double? rotation,
  }) =>
      AlignmentMeta(
        dx: dx ?? this.dx,
        dy: dy ?? this.dy,
        scale: scale ?? this.scale,
        rotation: rotation ?? this.rotation,
      );

  Map<String, dynamic> toMap() => {
        'dx': dx,
        'dy': dy,
        'scale': scale,
        'rotation': rotation,
      };

  factory AlignmentMeta.fromMap(Map<String, dynamic> map) => AlignmentMeta(
        dx: (map['dx'] as num?)?.toDouble() ?? 0,
        dy: (map['dy'] as num?)?.toDouble() ?? 0,
        scale: (map['scale'] as num?)?.toDouble() ?? 1.0,
        rotation: (map['rotation'] as num?)?.toDouble() ?? 0,
      );

  /// 각도(도) 편의 접근자.
  double get rotationDegrees => rotation * 180 / math.pi;
}

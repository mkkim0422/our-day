/// 자동 스토리 분류 종류(시간·장소 메타데이터 기반).
enum StoryKind {
  /// 집에서 먼 곳에서 연속으로 찍은 묶음.
  trip,

  /// 하루에 많이 찍은 날(여행에 속하지 않는).
  oneDay,

  /// 한 달 단위 묶음.
  monthly,
}

/// 스토리 생성 입력 — 사진 한 장의 메타데이터(갤러리 AssetEntity에서 추출).
class StoryPhoto {
  const StoryPhoto({
    required this.id,
    required this.takenAt,
    this.lat,
    this.lng,
  });

  final String id;
  final DateTime takenAt;
  final double? lat;
  final double? lng;

  bool get hasLocation => lat != null && lng != null;
}

/// 자동 생성된 스토리 1개.
class Story {
  const Story({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.coverPhotoId,
    required this.photoIds,
    required this.start,
    required this.end,
  });

  final StoryKind kind;
  final String title;
  final String subtitle;
  final String coverPhotoId;
  final List<String> photoIds;
  final DateTime start;
  final DateTime end;

  int get count => photoIds.length;
}

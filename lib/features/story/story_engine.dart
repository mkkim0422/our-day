import '../../core/utils/geo_distance.dart';
import 'story_models.dart';

/// 스토리 생성 임계값(테스트·튜닝용 주입 가능).
class StoryConfig {
  const StoryConfig({
    this.homeRadiusM = 30000, // 집에서 30km 밖이면 '여행' 후보
    this.tripGapDays = 2, // 여행 사진 사이 최대 공백(이상이면 다른 여행)
    this.minTripPhotos = 5,
    this.minDayPhotos = 8,
    this.minMonthPhotos = 12,
    this.maxStories = 40,
  });

  final double homeRadiusM;
  final int tripGapDays;
  final int minTripPhotos;
  final int minDayPhotos;
  final int minMonthPhotos;
  final int maxStories;
}

/// 사진 메타데이터(날짜·GPS)만으로 스토리를 자동 분류하는 순수 엔진(AI 없음).
///
/// - **여행(trip)**: 집(가장 사진이 몰린 곳)에서 먼 곳에서 며칠 연속 찍은 묶음.
/// - **어느 날(oneDay)**: 하루에 많이 찍은 날(여행에 속하지 않는).
/// - **이달의 기록(monthly)**: 한 달에 충분히 쌓인 묶음.
///
/// 외부 의존이 없어 단위 테스트가 쉽고, 갤러리 스캔 결과를 그대로 넣어 쓴다.
class StoryEngine {
  const StoryEngine([this.config = const StoryConfig()]);

  final StoryConfig config;

  List<Story> generate(List<StoryPhoto> photos, {required DateTime now}) {
    // 미래로 잘못 찍힌 EXIF(기기 시계 오류)는 제외.
    final sorted = photos.where((p) => !p.takenAt.isAfter(now)).toList()
      ..sort((a, b) => a.takenAt.compareTo(b.takenAt));
    if (sorted.isEmpty) return const [];

    final home = _detectHome(sorted);
    final trips = _trips(sorted, home);
    final tripRanges =
        trips.map((t) => (start: t.start, end: t.end)).toList();
    final days = _dayHighlights(sorted, tripRanges);
    final months = _months(sorted);

    final all = [...trips, ...days, ...months]
      ..sort((a, b) => b.end.compareTo(a.end)); // 최신 스토리 먼저
    return all.length <= config.maxStories
        ? all
        : all.sublist(0, config.maxStories);
  }

  /// 집 좌표 추정 — 0.1° 격자에서 가장 사진이 몰린 셀의 평균 좌표. GPS 없으면 null.
  (double, double)? _detectHome(List<StoryPhoto> photos) {
    final geo = photos.where((p) => p.hasLocation).toList();
    if (geo.isEmpty) return null;
    final cells = <String, List<StoryPhoto>>{};
    for (final p in geo) {
      final key = '${(p.lat! * 10).round()}_${(p.lng! * 10).round()}';
      (cells[key] ??= []).add(p);
    }
    final best = cells.values.reduce((a, b) => a.length >= b.length ? a : b);
    final lat = best.fold<double>(0, (s, p) => s + p.lat!) / best.length;
    final lng = best.fold<double>(0, (s, p) => s + p.lng!) / best.length;
    return (lat, lng);
  }

  List<Story> _trips(List<StoryPhoto> sorted, (double, double)? home) {
    if (home == null) return const [];
    final away = sorted
        .where((p) =>
            p.hasLocation &&
            GeoDistance.haversineMeters(home.$1, home.$2, p.lat!, p.lng!) >
                config.homeRadiusM)
        .toList(); // sorted의 부분집합이라 시간순 유지

    final runs = <List<StoryPhoto>>[];
    var cur = <StoryPhoto>[];
    for (final p in away) {
      if (cur.isEmpty) {
        cur = [p];
        continue;
      }
      final gap = p.takenAt.difference(cur.last.takenAt).inDays;
      if (gap <= config.tripGapDays) {
        cur.add(p);
      } else {
        runs.add(cur);
        cur = [p];
      }
    }
    if (cur.isNotEmpty) runs.add(cur);

    final stories = <Story>[];
    for (final run in runs) {
      if (run.length < config.minTripPhotos) continue;
      stories.add(Story(
        kind: StoryKind.trip,
        title: '여행',
        subtitle: '${_ym(run.first.takenAt)} · ${run.length}장',
        coverPhotoId: run[run.length ~/ 2].id,
        photoIds: run.map((p) => p.id).toList(),
        start: run.first.takenAt,
        end: run.last.takenAt,
      ));
    }
    return stories;
  }

  List<Story> _dayHighlights(
    List<StoryPhoto> sorted,
    List<({DateTime start, DateTime end})> tripRanges,
  ) {
    final byDay = <int, List<StoryPhoto>>{};
    for (final p in sorted) {
      (byDay[_dayKey(p.takenAt)] ??= []).add(p);
    }

    bool inTrip(DateTime d) {
      final day = DateTime(d.year, d.month, d.day);
      return tripRanges.any((r) {
        final s = DateTime(r.start.year, r.start.month, r.start.day);
        final e = DateTime(r.end.year, r.end.month, r.end.day);
        return !day.isBefore(s) && !day.isAfter(e);
      });
    }

    final stories = <Story>[];
    for (final list in byDay.values) {
      if (list.length < config.minDayPhotos) continue;
      final day = list.first.takenAt;
      if (inTrip(day)) continue;
      stories.add(Story(
        kind: StoryKind.oneDay,
        title: _ymd(day),
        subtitle: '그날의 기록 · ${list.length}장',
        coverPhotoId: list[list.length ~/ 2].id,
        photoIds: list.map((p) => p.id).toList(),
        start: list.first.takenAt,
        end: list.last.takenAt,
      ));
    }
    return stories;
  }

  List<Story> _months(List<StoryPhoto> sorted) {
    final byMonth = <String, List<StoryPhoto>>{};
    for (final p in sorted) {
      (byMonth['${p.takenAt.year}-${p.takenAt.month}'] ??= []).add(p);
    }
    final stories = <Story>[];
    for (final list in byMonth.values) {
      if (list.length < config.minMonthPhotos) continue;
      final d = list.first.takenAt;
      stories.add(Story(
        kind: StoryKind.monthly,
        title: '${d.year}년 ${d.month}월',
        subtitle: '이달의 기록 · ${list.length}장',
        coverPhotoId: list[list.length ~/ 2].id,
        photoIds: list.map((p) => p.id).toList(),
        start: list.first.takenAt,
        end: list.last.takenAt,
      ));
    }
    return stories;
  }

  int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;
  String _ym(DateTime d) => '${d.year}년 ${d.month}월';
  String _ymd(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
}

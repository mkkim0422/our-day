import 'package:flutter_test/flutter_test.dart';
import 'package:our_day/features/story/story_engine.dart';
import 'package:our_day/features/story/story_models.dart';

void main() {
  const engine = StoryEngine();
  final now = DateTime(2026, 6, 29);

  // 집(서울 근처)·여행지(부산, 약 325km)
  const homeLat = 37.5, homeLng = 127.0;
  const busanLat = 35.1, busanLng = 129.0;

  StoryPhoto at(String id, DateTime t, [double? lat, double? lng]) =>
      StoryPhoto(id: id, takenAt: t, lat: lat, lng: lng);

  test('빈 입력 → 빈 결과', () {
    expect(engine.generate(const [], now: now), isEmpty);
  });

  test('여행: 집에서 먼 곳 연속 촬영을 하나의 trip으로 묶는다', () {
    final photos = <StoryPhoto>[
      // 집에서 평소 사진(여러 달) — 집 좌표가 가장 밀집되게.
      for (var i = 0; i < 10; i++)
        at('home$i', DateTime(2024, 1 + i, 5), homeLat, homeLng),
      // 부산 여행 6장 (06/10~06/12 연속)
      at('t1', DateTime(2024, 6, 10, 9), busanLat, busanLng),
      at('t2', DateTime(2024, 6, 10, 14), busanLat, busanLng),
      at('t3', DateTime(2024, 6, 11, 10), busanLat, busanLng),
      at('t4', DateTime(2024, 6, 11, 16), busanLat, busanLng),
      at('t5', DateTime(2024, 6, 12, 11), busanLat, busanLng),
      at('t6', DateTime(2024, 6, 12, 18), busanLat, busanLng),
    ];
    final stories = engine.generate(photos, now: now);
    final trips = stories.where((s) => s.kind == StoryKind.trip).toList();
    expect(trips, hasLength(1));
    expect(trips.first.count, 6);
    expect(trips.first.title, '여행');
    expect(trips.first.photoIds, containsAll(['t1', 't6']));
  });

  test('여행: 최소 장수 미만이면 trip이 아니다', () {
    final photos = <StoryPhoto>[
      for (var i = 0; i < 10; i++)
        at('home$i', DateTime(2024, 1 + i, 5), homeLat, homeLng),
      at('t1', DateTime(2024, 6, 10), busanLat, busanLng),
      at('t2', DateTime(2024, 6, 10), busanLat, busanLng),
    ];
    final stories = engine.generate(photos, now: now);
    expect(stories.where((s) => s.kind == StoryKind.trip), isEmpty);
  });

  test('어느 날: 하루에 많이 찍은 날(여행 아님)을 oneDay로 묶는다', () {
    final photos = <StoryPhoto>[
      for (var i = 0; i < 9; i++)
        at('d$i', DateTime(2024, 5, 1, 9 + i), homeLat, homeLng),
    ];
    final stories = engine.generate(photos, now: now);
    final days = stories.where((s) => s.kind == StoryKind.oneDay).toList();
    expect(days, hasLength(1));
    expect(days.first.count, 9);
    expect(days.first.title, '2024.05.01');
  });

  test('GPS가 없어도 시간 기반(어느 날·이달) 분류는 동작한다', () {
    final photos = <StoryPhoto>[
      for (var i = 0; i < 12; i++) at('m$i', DateTime(2024, 3, 1 + i)),
    ];
    final stories = engine.generate(photos, now: now);
    expect(stories.where((s) => s.kind == StoryKind.trip), isEmpty);
    expect(stories.where((s) => s.kind == StoryKind.monthly), hasLength(1));
  });

  test('미래 날짜(잘못된 EXIF)는 제외한다', () {
    final photos = <StoryPhoto>[
      for (var i = 0; i < 9; i++)
        at('future$i', DateTime(2027, 1, 1, 9 + i), homeLat, homeLng),
    ];
    expect(engine.generate(photos, now: now), isEmpty);
  });
}

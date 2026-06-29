import 'package:flutter_test/flutter_test.dart';
import 'package:our_day/core/constants/enums.dart';
import 'package:our_day/data/db/app_database.dart';
import 'package:our_day/features/story/growth_story.dart';

Capture cap(String id, DateTime date, {String? placeId}) => Capture(
      id: id,
      projectId: 'p1',
      filePath: '/c/$id.jpg',
      thumbPath: '/t/$id.jpg',
      capturedAt: date,
      periodLabel: '',
      backupState: BackupState.localOnly,
      placeId: placeId,
    );

void main() {
  test('연도별: 같은 해 3컷 이상이면 묶는다', () {
    final caps = [
      cap('a', DateTime(2025, 1, 1)),
      cap('b', DateTime(2025, 5, 1)),
      cap('c', DateTime(2025, 9, 1)),
      cap('d', DateTime(2024, 3, 1)), // 2024는 1컷 → 미만
    ];
    final stories = GrowthStoryBuilder.build(capturesAsc: caps);
    final years = stories.where((s) => s.kind == GrowthStoryKind.year).toList();
    expect(years, hasLength(1));
    expect(years.first.title, '2025년의 성장');
    expect(years.first.count, 3);
  });

  test('장소별: 라벨이 있고 2컷 이상이면 묶는다', () {
    final caps = [
      cap('a', DateTime(2025, 1, 1), placeId: 'gm'),
      cap('b', DateTime(2025, 2, 1), placeId: 'gm'),
      cap('c', DateTime(2025, 3, 1), placeId: 'solo'), // 1컷 → 미만
    ];
    final stories = GrowthStoryBuilder.build(
      capturesAsc: caps,
      placeLabels: {'gm': '할머니집'},
    );
    final places =
        stories.where((s) => s.kind == GrowthStoryKind.place).toList();
    expect(places, hasLength(1));
    expect(places.first.title, '할머니집에서');
  });

  test('첫 1년: 생일 기준 첫 해 사진을 묶는다', () {
    final birthday = DateTime(2024, 3, 1);
    final caps = [
      cap('a', DateTime(2024, 4, 1)),
      cap('b', DateTime(2024, 8, 1)),
      cap('c', DateTime(2025, 1, 1)),
      cap('d', DateTime(2025, 6, 1)), // 첫 1년 밖(2025-03-01 이후)
    ];
    final stories =
        GrowthStoryBuilder.build(capturesAsc: caps, birthday: birthday);
    final ms =
        stories.where((s) => s.kind == GrowthStoryKind.milestone).toList();
    expect(ms, hasLength(1));
    expect(ms.first.title, '첫 1년의 기록');
    expect(ms.first.count, 3);
  });

  test('구성원별: 태그된 사진 2컷 이상이면 묶는다', () {
    final caps = [cap('a', DateTime(2025, 1, 1)), cap('b', DateTime(2025, 2, 1))];
    final stories = GrowthStoryBuilder.build(
      capturesAsc: const [],
      memberGroups: [(name: '엄마', captures: caps)],
    );
    final m = stories.where((s) => s.kind == GrowthStoryKind.member).toList();
    expect(m, hasLength(1));
    expect(m.first.title, '엄마와 함께');
  });

  test('임계 미만이면 스토리가 없다', () {
    final stories = GrowthStoryBuilder.build(
      capturesAsc: [cap('a', DateTime(2025, 1, 1))],
    );
    expect(stories, isEmpty);
  });
}

import '../../data/db/app_database.dart';

/// 성장기록 컨셉에 맞춘 스토리 종류(우리 앱 사진 기반 — 폰 전체 갤러리 아님).
enum GrowthStoryKind { milestone, year, place, member }

/// 자동 생성된 성장 스토리 1개(아이·가족 중심).
class GrowthStory {
  const GrowthStory(this.kind, this.title, this.subtitle, this.captures);

  final GrowthStoryKind kind;
  final String title;
  final String subtitle;

  /// 시간순(오래된→최근) 정렬된 사진들.
  final List<Capture> captures;

  int get count => captures.length;

  /// 대표 사진 — 가장 최근(꾸민 게 있으면 그걸).
  Capture get cover => captures.last;
}

/// 우리 앱 성장사진으로 스토리를 만든다(시간·장소·구성원·마일스톤). 순수·테스트 용이.
///
/// 갤럭시처럼 폰 전체를 훑지 않고, **이미 가진 데이터**(촬영일·장소·구성원태그·생일)
/// 로만 묶어 "이 아이의 성장"이라는 우리만의 스토리를 만든다.
class GrowthStoryBuilder {
  const GrowthStoryBuilder._();

  static List<GrowthStory> build({
    required List<Capture> capturesAsc,
    Map<String, String> placeLabels = const {},
    List<({String name, List<Capture> captures})> memberGroups = const [],
    DateTime? birthday,
    int minYear = 3,
    int minPlace = 2,
    int minMember = 2,
    int minFirstYear = 3,
  }) {
    final stories = <GrowthStory>[];

    // 1) 첫 1년의 기록(생일이 있을 때) — 가장 감동적인 묶음.
    if (birthday != null) {
      final end = DateTime(birthday.year + 1, birthday.month, birthday.day);
      final firstYear = capturesAsc
          .where((c) =>
              !c.capturedAt.isBefore(birthday) && c.capturedAt.isBefore(end))
          .toList();
      if (firstYear.length >= minFirstYear) {
        stories.add(GrowthStory(GrowthStoryKind.milestone, '첫 1년의 기록',
            '${firstYear.length}컷', firstYear));
      }
    }

    // 2) 연도별 성장(최신 연도 먼저).
    final byYear = <int, List<Capture>>{};
    for (final c in capturesAsc) {
      (byYear[c.capturedAt.year] ??= []).add(c);
    }
    final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final y in years) {
      final list = byYear[y]!;
      if (list.length >= minYear) {
        stories.add(
            GrowthStory(GrowthStoryKind.year, '$y년의 성장', '${list.length}컷', list));
      }
    }

    // 3) 장소별("○○에서").
    final byPlace = <String, List<Capture>>{};
    for (final c in capturesAsc) {
      final pid = c.placeId;
      if (pid != null) (byPlace[pid] ??= []).add(c);
    }
    byPlace.forEach((pid, list) {
      final label = placeLabels[pid];
      if (list.length >= minPlace && label != null && label.isNotEmpty) {
        stories.add(GrowthStory(
            GrowthStoryKind.place, '$label에서', '${list.length}컷', list));
      }
    });

    // 4) 구성원별("○○와 함께").
    for (final g in memberGroups) {
      if (g.captures.length >= minMember) {
        stories.add(GrowthStory(GrowthStoryKind.member, '${g.name}와 함께',
            '${g.captures.length}컷', g.captures));
      }
    }

    return stories;
  }
}

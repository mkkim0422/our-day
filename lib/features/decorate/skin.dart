import 'package:flutter/material.dart';

import 'decor_models.dart';
import 'decor_motifs.dart';

/// 프리미엄 "스킨" — 팔레트·프레임·필터·폰트·모티프·성장데이터 레이아웃을 한 디자인으로
/// 묶은 큐레이션 템플릿(유료 가족앱의 마일스톤 카드 감성). [SkinCard]가 렌더한다.

/// 프레임 형태.
enum SkinFrame {
  plain, // 매트 + 둥근 사진
  polaroid, // 하단 두꺼운 여백(문구 자리)
  film, // 필름 스트립(상하 perforation)
  arch, // 아치형 상단 마스크
  inset, // 사진 안쪽 얇은 라인 액자
}

/// 스킨 카테고리(탭).
enum SkinCategory { minimal, lovely, baby, birthday, season, vintage }

const Map<SkinCategory, String> kCategoryNames = {
  SkinCategory.minimal: '미니멀',
  SkinCategory.lovely: '러블리',
  SkinCategory.baby: '베이비',
  SkinCategory.birthday: '생일',
  SkinCategory.season: '계절',
  SkinCategory.vintage: '빈티지',
};

@immutable
class Skin {
  const Skin({
    required this.id,
    required this.name,
    required this.category,
    required this.bg,
    required this.frame,
    required this.filter,
    required this.accent,
    required this.font,
    this.accent2,
    this.motifs = const [],
  });

  final String id;
  final String name;
  final SkinCategory category;
  final List<Color> bg; // 1색=단색, 2색=그라데이션
  final SkinFrame frame;
  final List<double>? filter; // ColorFilter.matrix (null=원본)
  final Color accent; // 글자·라인 강조색
  final Color? accent2;
  final String font; // google_fonts 패밀리
  final List<Motif> motifs;

  ColorFilter? get colorFilter =>
      filter == null ? null : ColorFilter.matrix(filter!);
}

DecorFilter _f(String n) => kFilters.firstWhere((e) => e.name == n);

/// 큐레이션 스킨 — 카테고리별 다수(유료앱급 다양성).
final List<Skin> kSkins = [
  // ── 미니멀 ──
  Skin(
    id: 'm_clean',
    name: '클린',
    category: SkinCategory.minimal,
    bg: const [Color(0xFFFFFFFF)],
    frame: SkinFrame.polaroid,
    filter: _f('원본').matrix,
    accent: const Color(0xFF2B2B2E),
    font: 'Do Hyeon',
  ),
  Skin(
    id: 'm_ivory',
    name: '아이보리',
    category: SkinCategory.minimal,
    bg: const [Color(0xFFF7F3EC)],
    frame: SkinFrame.inset,
    filter: _f('따뜻').matrix,
    accent: const Color(0xFF8A7B66),
    font: 'Song Myung',
  ),
  Skin(
    id: 'm_mono',
    name: '모노',
    category: SkinCategory.minimal,
    bg: const [Color(0xFFEDEFF2)],
    frame: SkinFrame.plain,
    filter: _f('흑백').matrix,
    accent: const Color(0xFF2B2B2E),
    font: 'Black Han Sans',
  ),
  Skin(
    id: 'm_arch',
    name: '아치',
    category: SkinCategory.minimal,
    bg: const [Color(0xFFF2ECE3)],
    frame: SkinFrame.arch,
    filter: _f('페이드').matrix,
    accent: const Color(0xFFB08968),
    font: 'Gugi',
    motifs: [Motif.arch],
  ),

  // ── 러블리 ──
  Skin(
    id: 'l_blush',
    name: '블러시',
    category: SkinCategory.lovely,
    bg: const [Color(0xFFFDE7EF)],
    frame: SkinFrame.polaroid,
    filter: _f('드리미').matrix,
    accent: const Color(0xFFC65B86),
    accent2: Color(0xFFF7A8C4),
    font: 'Gaegu',
    motifs: [Motif.hearts, Motif.sparkle],
  ),
  Skin(
    id: 'l_dots',
    name: '도트하트',
    category: SkinCategory.lovely,
    bg: const [Color(0xFFFFF1F5)],
    frame: SkinFrame.inset,
    filter: _f('따뜻').matrix,
    accent: const Color(0xFFD06A8C),
    font: 'Hi Melody',
    motifs: [Motif.dottedBorder, Motif.hearts],
  ),
  Skin(
    id: 'l_sweet',
    name: '스위트',
    category: SkinCategory.lovely,
    bg: const [Color(0xFFFFE3EC), Color(0xFFFFD9C0)],
    frame: SkinFrame.polaroid,
    filter: _f('드리미').matrix,
    accent: const Color(0xFFB85C7A),
    accent2: Color(0xFFFFB07C),
    font: 'Nanum Pen Script',
    motifs: [Motif.sparkle],
  ),

  // ── 베이비 ──
  Skin(
    id: 'b_cloud',
    name: '구름',
    category: SkinCategory.baby,
    bg: const [Color(0xFFE6F0FB)],
    frame: SkinFrame.polaroid,
    filter: _f('드리미').matrix,
    accent: const Color(0xFF5B86B0),
    accent2: Color(0xFFFFD36E),
    font: 'Jua',
    motifs: [Motif.stars, Motif.sunRays],
  ),
  Skin(
    id: 'b_mint',
    name: '민트베이비',
    category: SkinCategory.baby,
    bg: const [Color(0xFFE3F4ED)],
    frame: SkinFrame.inset,
    filter: _f('원본').matrix,
    accent: const Color(0xFF3F8E78),
    font: 'Gamja Flower',
    motifs: [Motif.leaves],
  ),
  Skin(
    id: 'b_rainbow',
    name: '레인보우',
    category: SkinCategory.baby,
    bg: const [Color(0xFFFFFDF5)],
    frame: SkinFrame.plain,
    filter: _f('생생').matrix,
    accent: const Color(0xFF6B8E9F),
    font: 'Jua',
    motifs: [Motif.rainbow, Motif.stars],
  ),
  Skin(
    id: 'b_star',
    name: '꿈나라',
    category: SkinCategory.baby,
    bg: const [Color(0xFFEDE6FA), Color(0xFFD6E8FF)],
    frame: SkinFrame.polaroid,
    filter: _f('드리미').matrix,
    accent: const Color(0xFF6E5B9E),
    accent2: Color(0xFFFFD36E),
    font: 'Dongle',
    motifs: [Motif.stars, Motif.sparkle],
  ),

  // ── 생일 ──
  Skin(
    id: 'p_party',
    name: '파티',
    category: SkinCategory.birthday,
    bg: const [Color(0xFFFFF6D6)],
    frame: SkinFrame.polaroid,
    filter: _f('생생').matrix,
    accent: const Color(0xFFE0556F),
    accent2: Color(0xFF59B0C4),
    font: 'Black Han Sans',
    motifs: [Motif.confetti, Motif.sparkle],
  ),
  Skin(
    id: 'p_cake',
    name: '케이크데이',
    category: SkinCategory.birthday,
    bg: const [Color(0xFFFFEAE0)],
    frame: SkinFrame.inset,
    filter: _f('따뜻').matrix,
    accent: const Color(0xFFD2694B),
    font: 'Gaegu',
    motifs: [Motif.confetti],
  ),
  Skin(
    id: 'p_gold',
    name: '골드데이',
    category: SkinCategory.birthday,
    bg: const [Color(0xFF2B2B33)],
    frame: SkinFrame.plain,
    filter: _f('필름').matrix,
    accent: const Color(0xFFE9C46A),
    accent2: Color(0xFFE9C46A),
    font: 'Gugi',
    motifs: [Motif.sparkle, Motif.stars],
  ),

  // ── 계절 ──
  Skin(
    id: 's_spring',
    name: '봄',
    category: SkinCategory.season,
    bg: const [Color(0xFFFDEFF3), Color(0xFFEAF6E9)],
    frame: SkinFrame.arch,
    filter: _f('드리미').matrix,
    accent: const Color(0xFFCE7A9A),
    font: 'Gamja Flower',
    motifs: [Motif.leaves, Motif.sparkle],
  ),
  Skin(
    id: 's_summer',
    name: '여름',
    category: SkinCategory.season,
    bg: const [Color(0xFFE6F7FB), Color(0xFFFFF6D6)],
    frame: SkinFrame.plain,
    filter: _f('시원').matrix,
    accent: const Color(0xFF2E8FA6),
    accent2: Color(0xFFFFD36E),
    font: 'Jua',
    motifs: [Motif.sunRays],
  ),
  Skin(
    id: 's_autumn',
    name: '가을',
    category: SkinCategory.season,
    bg: const [Color(0xFFF7EAD9)],
    frame: SkinFrame.inset,
    filter: _f('따뜻').matrix,
    accent: const Color(0xFFA9683B),
    font: 'Song Myung',
    motifs: [Motif.leaves],
  ),
  Skin(
    id: 's_winter',
    name: '겨울',
    category: SkinCategory.season,
    bg: const [Color(0xFFEAF1F7)],
    frame: SkinFrame.polaroid,
    filter: _f('시원').matrix,
    accent: const Color(0xFF5E7B97),
    accent2: Color(0xFFBFD8E8),
    font: 'Dongle',
    motifs: [Motif.sparkle, Motif.stars],
  ),

  // ── 빈티지 ──
  Skin(
    id: 'v_film',
    name: '필름',
    category: SkinCategory.vintage,
    bg: const [Color(0xFF1C1C1E)],
    frame: SkinFrame.film,
    filter: _f('필름').matrix,
    accent: const Color(0xFFE8E2D0),
    font: 'Do Hyeon',
  ),
  Skin(
    id: 'v_sepia',
    name: '세피아',
    category: SkinCategory.vintage,
    bg: const [Color(0xFFF1E7D6)],
    frame: SkinFrame.inset,
    filter: _f('세피아').matrix,
    accent: const Color(0xFF7A5C3E),
    font: 'Nanum Pen Script',
  ),
  Skin(
    id: 'v_retro',
    name: '레트로',
    category: SkinCategory.vintage,
    bg: const [Color(0xFFEFE3CF)],
    frame: SkinFrame.polaroid,
    filter: _f('페이드').matrix,
    accent: const Color(0xFFB5553C),
    accent2: Color(0xFF3F7E8E),
    font: 'Gugi',
    motifs: [Motif.sunRays],
  ),
];

List<Skin> skinsForCategory(SkinCategory c) =>
    kSkins.where((s) => s.category == c).toList();

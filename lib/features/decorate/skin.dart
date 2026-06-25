import 'package:flutter/material.dart';

import 'decor_models.dart';
import 'decor_motifs.dart';

/// 프리미엄 "스킨" — 팔레트·프레임·필터·폰트·모티프·성장데이터 레이아웃을 한 디자인으로
/// 묶은 큐레이션 템플릿(유료 가족앱의 마일스톤 카드 감성). [SkinCard]가 렌더한다.

/// 프레임 형태.
enum SkinFrame { plain, polaroid, film, arch, inset }

/// 스킨 카테고리(탭) — 다른 앱(StoryArt·Mostory·베이비앱) 벤치마킹해 12종.
enum SkinCategory {
  minimal,
  lovely,
  baby,
  birthday,
  season,
  vintage,
  magazine,
  diary,
  natural,
  aesthetic,
  holiday,
  mono,
}

const Map<SkinCategory, String> kCategoryNames = {
  SkinCategory.minimal: '미니멀',
  SkinCategory.lovely: '러블리',
  SkinCategory.baby: '베이비',
  SkinCategory.birthday: '생일',
  SkinCategory.season: '계절',
  SkinCategory.vintage: '빈티지',
  SkinCategory.magazine: '매거진',
  SkinCategory.diary: '다이어리',
  SkinCategory.natural: '내추럴',
  SkinCategory.aesthetic: '감성',
  SkinCategory.holiday: '홀리데이',
  SkinCategory.mono: '모노',
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
  final Color accent;
  final Color? accent2;
  final String font; // google_fonts 패밀리
  final List<Motif> motifs;

  ColorFilter? get colorFilter =>
      filter == null ? null : ColorFilter.matrix(filter!);
}

List<double>? _m(String n) => kFilters.firstWhere((e) => e.name == n).matrix;

/// 큐레이션 스킨 — 12 카테고리 × 5 = 60종(유료앱급 다양성).
final List<Skin> kSkins = [
  // ── 미니멀 ──
  Skin(id: 'm_clean', name: '클린', category: SkinCategory.minimal, bg: const [Color(0xFFFFFFFF)], frame: SkinFrame.polaroid, filter: _m('원본'), accent: const Color(0xFF2B2B2E), font: 'Do Hyeon'),
  Skin(id: 'm_ivory', name: '아이보리', category: SkinCategory.minimal, bg: const [Color(0xFFF7F3EC)], frame: SkinFrame.inset, filter: _m('따뜻'), accent: const Color(0xFF8A7B66), font: 'Song Myung'),
  Skin(id: 'm_paper', name: '페이퍼', category: SkinCategory.minimal, bg: const [Color(0xFFF4F1EA)], frame: SkinFrame.plain, filter: _m('페이드'), accent: const Color(0xFF5A5650), font: 'Gowun Dodum', motifs: [Motif.ruleLines]),
  Skin(id: 'm_arch', name: '아치', category: SkinCategory.minimal, bg: const [Color(0xFFF2ECE3)], frame: SkinFrame.arch, filter: _m('페이드'), accent: const Color(0xFFB08968), font: 'Gugi', motifs: [Motif.arch]),
  Skin(id: 'm_line', name: '라인', category: SkinCategory.minimal, bg: const [Color(0xFFFFFFFF)], frame: SkinFrame.inset, filter: _m('원본'), accent: const Color(0xFF2B2B2E), font: 'Gothic A1', motifs: [Motif.dottedBorder]),

  // ── 러블리 ──
  Skin(id: 'l_blush', name: '블러시', category: SkinCategory.lovely, bg: const [Color(0xFFFDE7EF)], frame: SkinFrame.polaroid, filter: _m('드리미'), accent: const Color(0xFFC65B86), accent2: const Color(0xFFF7A8C4), font: 'Gaegu', motifs: [Motif.hearts, Motif.sparkle]),
  Skin(id: 'l_dots', name: '도트하트', category: SkinCategory.lovely, bg: const [Color(0xFFFFF1F5)], frame: SkinFrame.inset, filter: _m('따뜻'), accent: const Color(0xFFD06A8C), font: 'Hi Melody', motifs: [Motif.dottedBorder, Motif.hearts]),
  Skin(id: 'l_sweet', name: '스위트', category: SkinCategory.lovely, bg: const [Color(0xFFFFE3EC), Color(0xFFFFD9C0)], frame: SkinFrame.polaroid, filter: _m('드리미'), accent: const Color(0xFFB85C7A), accent2: const Color(0xFFFFB07C), font: 'Nanum Pen Script', motifs: [Motif.sparkle]),
  Skin(id: 'l_candy', name: '캔디', category: SkinCategory.lovely, bg: const [Color(0xFFFCE1F0)], frame: SkinFrame.plain, filter: _m('생생'), accent: const Color(0xFFD14B86), accent2: const Color(0xFF9AD0E0), font: 'Cute Font', motifs: [Motif.hearts, Motif.confetti]),
  Skin(id: 'l_peach', name: '피치', category: SkinCategory.lovely, bg: const [Color(0xFFFFEAE0)], frame: SkinFrame.arch, filter: _m('따뜻'), accent: const Color(0xFFD2694B), font: 'Gamja Flower', motifs: [Motif.floral]),

  // ── 베이비 ──
  Skin(id: 'b_cloud', name: '구름', category: SkinCategory.baby, bg: const [Color(0xFFE6F0FB)], frame: SkinFrame.polaroid, filter: _m('드리미'), accent: const Color(0xFF5B86B0), accent2: const Color(0xFFFFD36E), font: 'Jua', motifs: [Motif.stars, Motif.sunRays]),
  Skin(id: 'b_mint', name: '민트', category: SkinCategory.baby, bg: const [Color(0xFFE3F4ED)], frame: SkinFrame.inset, filter: _m('원본'), accent: const Color(0xFF3F8E78), font: 'Gamja Flower', motifs: [Motif.leaves]),
  Skin(id: 'b_rainbow', name: '레인보우', category: SkinCategory.baby, bg: const [Color(0xFFFFFDF5)], frame: SkinFrame.plain, filter: _m('생생'), accent: const Color(0xFF6B8E9F), font: 'Jua', motifs: [Motif.rainbow, Motif.stars]),
  Skin(id: 'b_star', name: '꿈나라', category: SkinCategory.baby, bg: const [Color(0xFFEDE6FA), Color(0xFFD6E8FF)], frame: SkinFrame.polaroid, filter: _m('드리미'), accent: const Color(0xFF6E5B9E), accent2: const Color(0xFFFFD36E), font: 'Dongle', motifs: [Motif.stars, Motif.sparkle]),
  Skin(id: 'b_bunny', name: '토끼풍선', category: SkinCategory.baby, bg: const [Color(0xFFFFF3E2)], frame: SkinFrame.inset, filter: _m('따뜻'), accent: const Color(0xFFB07A4A), accent2: const Color(0xFF8FB996), font: 'Gaegu', motifs: [Motif.bunting]),

  // ── 생일 ──
  Skin(id: 'p_party', name: '파티', category: SkinCategory.birthday, bg: const [Color(0xFFFFF6D6)], frame: SkinFrame.polaroid, filter: _m('생생'), accent: const Color(0xFFE0556F), accent2: const Color(0xFF59B0C4), font: 'Black Han Sans', motifs: [Motif.confetti, Motif.sparkle]),
  Skin(id: 'p_cake', name: '케이크데이', category: SkinCategory.birthday, bg: const [Color(0xFFFFEAE0)], frame: SkinFrame.inset, filter: _m('따뜻'), accent: const Color(0xFFD2694B), font: 'Gaegu', motifs: [Motif.confetti]),
  Skin(id: 'p_gold', name: '골드데이', category: SkinCategory.birthday, bg: const [Color(0xFF2B2B33)], frame: SkinFrame.plain, filter: _m('필름'), accent: const Color(0xFFE9C46A), accent2: const Color(0xFFE9C46A), font: 'Gugi', motifs: [Motif.sparkle, Motif.stars]),
  Skin(id: 'p_bunting', name: '가랜드', category: SkinCategory.birthday, bg: const [Color(0xFFFFF7E8)], frame: SkinFrame.polaroid, filter: _m('생생'), accent: const Color(0xFFE26D5C), accent2: const Color(0xFF3F8E78), font: 'Jua', motifs: [Motif.bunting]),
  Skin(id: 'p_pop', name: '팝', category: SkinCategory.birthday, bg: const [Color(0xFFF2E9FF)], frame: SkinFrame.plain, filter: _m('생생'), accent: const Color(0xFF7A4FD0), accent2: const Color(0xFFFFC36B), font: 'Yeon Sung', motifs: [Motif.confetti, Motif.stars]),

  // ── 계절 ──
  Skin(id: 's_spring', name: '봄', category: SkinCategory.season, bg: const [Color(0xFFFDEFF3), Color(0xFFEAF6E9)], frame: SkinFrame.arch, filter: _m('드리미'), accent: const Color(0xFFCE7A9A), font: 'Gamja Flower', motifs: [Motif.floral, Motif.sparkle]),
  Skin(id: 's_summer', name: '여름', category: SkinCategory.season, bg: const [Color(0xFFE6F7FB), Color(0xFFFFF6D6)], frame: SkinFrame.plain, filter: _m('시원'), accent: const Color(0xFF2E8FA6), accent2: const Color(0xFFFFD36E), font: 'Jua', motifs: [Motif.sunRays]),
  Skin(id: 's_autumn', name: '가을', category: SkinCategory.season, bg: const [Color(0xFFF7EAD9)], frame: SkinFrame.inset, filter: _m('따뜻'), accent: const Color(0xFFA9683B), font: 'Song Myung', motifs: [Motif.fern]),
  Skin(id: 's_winter', name: '겨울', category: SkinCategory.season, bg: const [Color(0xFFEAF1F7)], frame: SkinFrame.polaroid, filter: _m('시원'), accent: const Color(0xFF5E7B97), accent2: const Color(0xFFBFD8E8), font: 'Dongle', motifs: [Motif.snow, Motif.sparkle]),
  Skin(id: 's_cherry', name: '벚꽃', category: SkinCategory.season, bg: const [Color(0xFFFFF0F3)], frame: SkinFrame.plain, filter: _m('드리미'), accent: const Color(0xFFD06A8C), font: 'Nanum Pen Script', motifs: [Motif.floral]),

  // ── 빈티지 ──
  Skin(id: 'v_film', name: '필름', category: SkinCategory.vintage, bg: const [Color(0xFF1C1C1E)], frame: SkinFrame.film, filter: _m('필름'), accent: const Color(0xFFE8E2D0), font: 'Do Hyeon'),
  Skin(id: 'v_sepia', name: '세피아', category: SkinCategory.vintage, bg: const [Color(0xFFF1E7D6)], frame: SkinFrame.inset, filter: _m('세피아'), accent: const Color(0xFF7A5C3E), font: 'Nanum Pen Script'),
  Skin(id: 'v_retro', name: '레트로', category: SkinCategory.vintage, bg: const [Color(0xFFEFE3CF)], frame: SkinFrame.polaroid, filter: _m('페이드'), accent: const Color(0xFFB5553C), accent2: const Color(0xFF3F7E8E), font: 'Gugi', motifs: [Motif.sunRays]),
  Skin(id: 'v_classic', name: '70s', category: SkinCategory.vintage, bg: const [Color(0xFFE9DCC2)], frame: SkinFrame.inset, filter: _m('세피아'), accent: const Color(0xFF6B4F2E), font: 'Song Myung', motifs: [Motif.ruleLines]),
  Skin(id: 'v_oldfilm', name: '올드필름', category: SkinCategory.vintage, bg: const [Color(0xFF232018)], frame: SkinFrame.film, filter: _m('세피아'), accent: const Color(0xFFD8C9A0), font: 'Do Hyeon'),

  // ── 매거진 ──
  Skin(id: 'mg_vogue', name: '보그', category: SkinCategory.magazine, bg: const [Color(0xFFFFFFFF)], frame: SkinFrame.inset, filter: _m('흑백'), accent: const Color(0xFF1A1A1A), font: 'Black Han Sans', motifs: [Motif.ruleLines]),
  Skin(id: 'mg_editor', name: '에디토리얼', category: SkinCategory.magazine, bg: const [Color(0xFFF5F3EF)], frame: SkinFrame.plain, filter: _m('페이드'), accent: const Color(0xFF2B2B2E), font: 'Song Myung', motifs: [Motif.ruleLines]),
  Skin(id: 'mg_bold', name: '볼드', category: SkinCategory.magazine, bg: const [Color(0xFFFFFFFF)], frame: SkinFrame.inset, filter: _m('생생'), accent: const Color(0xFFE03E52), font: 'Black Han Sans', motifs: [Motif.ruleLines]),
  Skin(id: 'mg_kraft', name: '크라프트', category: SkinCategory.magazine, bg: const [Color(0xFFE7DECB)], frame: SkinFrame.plain, filter: _m('세피아'), accent: const Color(0xFF4A3B28), font: 'Stylish', motifs: [Motif.ruleLines]),
  Skin(id: 'mg_noir', name: '느와르', category: SkinCategory.magazine, bg: const [Color(0xFF1A1A1A)], frame: SkinFrame.plain, filter: _m('흑백'), accent: const Color(0xFFEDEDED), font: 'Gugi', motifs: [Motif.ruleLines]),

  // ── 다이어리 ──
  Skin(id: 'd_washi', name: '워시', category: SkinCategory.diary, bg: const [Color(0xFFFFF8EC)], frame: SkinFrame.polaroid, filter: _m('따뜻'), accent: const Color(0xFFC77B57), accent2: const Color(0xFF8FB996), font: 'Gaegu', motifs: [Motif.washiTape]),
  Skin(id: 'd_grid', name: '모눈', category: SkinCategory.diary, bg: const [Color(0xFFFBF7EF)], frame: SkinFrame.inset, filter: _m('원본'), accent: const Color(0xFF6B5A52), font: 'Gowun Dodum', motifs: [Motif.washiTape, Motif.dottedBorder]),
  Skin(id: 'd_memo', name: '메모', category: SkinCategory.diary, bg: const [Color(0xFFFFF6E9)], frame: SkinFrame.plain, filter: _m('페이드'), accent: const Color(0xFFB5553C), font: 'Nanum Pen Script', motifs: [Motif.washiTape]),
  Skin(id: 'd_pastel', name: '파스텔', category: SkinCategory.diary, bg: const [Color(0xFFF2ECFB)], frame: SkinFrame.polaroid, filter: _m('드리미'), accent: const Color(0xFF7A5BA6), accent2: const Color(0xFFF7A8C4), font: 'Hi Melody', motifs: [Motif.washiTape, Motif.hearts]),
  Skin(id: 'd_kraft', name: '크라프트', category: SkinCategory.diary, bg: const [Color(0xFFEADBC4)], frame: SkinFrame.inset, filter: _m('세피아'), accent: const Color(0xFF5C4326), font: 'Stylish', motifs: [Motif.washiTape]),

  // ── 내추럴 ──
  Skin(id: 'n_olive', name: '올리브', category: SkinCategory.natural, bg: const [Color(0xFFF0EFE3)], frame: SkinFrame.inset, filter: _m('페이드'), accent: const Color(0xFF6B7B4A), font: 'Gowun Batang', motifs: [Motif.leaves]),
  Skin(id: 'n_fern', name: '고사리', category: SkinCategory.natural, bg: const [Color(0xFFEAF0E6)], frame: SkinFrame.plain, filter: _m('원본'), accent: const Color(0xFF4F6B4A), font: 'Gamja Flower', motifs: [Motif.fern]),
  Skin(id: 'n_sage', name: '세이지', category: SkinCategory.natural, bg: const [Color(0xFFE7EDE6)], frame: SkinFrame.polaroid, filter: _m('시원'), accent: const Color(0xFF5E7359), font: 'Song Myung', motifs: [Motif.leaves]),
  Skin(id: 'n_terra', name: '테라코타', category: SkinCategory.natural, bg: const [Color(0xFFF3E7DC)], frame: SkinFrame.inset, filter: _m('따뜻'), accent: const Color(0xFFA2613B), font: 'Hahmlet', motifs: [Motif.fern]),
  Skin(id: 'n_bloom', name: '블룸', category: SkinCategory.natural, bg: const [Color(0xFFFBF1F0)], frame: SkinFrame.arch, filter: _m('드리미'), accent: const Color(0xFFB07C8F), font: 'Nanum Myeongjo', motifs: [Motif.floral]),

  // ── 감성 ──
  Skin(id: 'a_film', name: '필름감성', category: SkinCategory.aesthetic, bg: const [Color(0xFFF3EDE3), Color(0xFFE7DDD0)], frame: SkinFrame.plain, filter: _m('필름'), accent: const Color(0xFF6B5D4F), font: 'Gowun Dodum'),
  Skin(id: 'a_dusty', name: '더스티', category: SkinCategory.aesthetic, bg: const [Color(0xFFE9E4E0)], frame: SkinFrame.inset, filter: _m('페이드'), accent: const Color(0xFF8A7F86), font: 'Song Myung'),
  Skin(id: 'a_haze', name: '헤이즈', category: SkinCategory.aesthetic, bg: const [Color(0xFFFCEFE6), Color(0xFFEFE2EA)], frame: SkinFrame.plain, filter: _m('드리미'), accent: const Color(0xFF9A6B7A), font: 'Nanum Myeongjo', motifs: [Motif.sparkle]),
  Skin(id: 'a_mood', name: '무드', category: SkinCategory.aesthetic, bg: const [Color(0xFFE6E2DC)], frame: SkinFrame.polaroid, filter: _m('페이드'), accent: const Color(0xFF5E5750), font: 'Gowun Batang'),
  Skin(id: 'a_grain', name: '그레인', category: SkinCategory.aesthetic, bg: const [Color(0xFF2A2622)], frame: SkinFrame.plain, filter: _m('필름'), accent: const Color(0xFFD8CFC2), font: 'Stylish'),

  // ── 홀리데이 ──
  Skin(id: 'h_xmas', name: '크리스마스', category: SkinCategory.holiday, bg: const [Color(0xFF1E3A2F), Color(0xFF2E5A44)], frame: SkinFrame.plain, filter: _m('필름'), accent: const Color(0xFFE9C46A), accent2: const Color(0xFFE03E52), font: 'Gugi', motifs: [Motif.snow, Motif.ornaments]),
  Skin(id: 'h_snow', name: '스노우', category: SkinCategory.holiday, bg: const [Color(0xFFEAF1F7)], frame: SkinFrame.polaroid, filter: _m('시원'), accent: const Color(0xFF4F6B8A), accent2: const Color(0xFFBFD8E8), font: 'Dongle', motifs: [Motif.snow]),
  Skin(id: 'h_newyear', name: '새해', category: SkinCategory.holiday, bg: const [Color(0xFF1A1A22)], frame: SkinFrame.plain, filter: _m('필름'), accent: const Color(0xFFE9C46A), font: 'Black Han Sans', motifs: [Motif.sparkle, Motif.stars]),
  Skin(id: 'h_warm', name: '따뜻한밤', category: SkinCategory.holiday, bg: const [Color(0xFF3A2A22)], frame: SkinFrame.plain, filter: _m('따뜻'), accent: const Color(0xFFE9C46A), accent2: const Color(0xFFE07A5F), font: 'Gaegu', motifs: [Motif.ornaments, Motif.snow]),
  Skin(id: 'h_candy', name: '캔디케인', category: SkinCategory.holiday, bg: const [Color(0xFFFBEEF0)], frame: SkinFrame.polaroid, filter: _m('생생'), accent: const Color(0xFFC0392B), accent2: const Color(0xFF2E8B57), font: 'Jua', motifs: [Motif.bunting, Motif.snow]),

  // ── 모노 ──
  Skin(id: 'mo_classic', name: '클래식', category: SkinCategory.mono, bg: const [Color(0xFFFFFFFF)], frame: SkinFrame.inset, filter: _m('흑백'), accent: const Color(0xFF1A1A1A), font: 'Song Myung'),
  Skin(id: 'mo_noir', name: '느와르', category: SkinCategory.mono, bg: const [Color(0xFF121212)], frame: SkinFrame.plain, filter: _m('흑백'), accent: const Color(0xFFEDEDED), font: 'Gugi'),
  Skin(id: 'mo_film', name: '필름B&W', category: SkinCategory.mono, bg: const [Color(0xFFF2F2F2)], frame: SkinFrame.film, filter: _m('흑백'), accent: const Color(0xFF1A1A1A), font: 'Do Hyeon'),
  Skin(id: 'mo_soft', name: '소프트', category: SkinCategory.mono, bg: const [Color(0xFFF4F1EC)], frame: SkinFrame.polaroid, filter: _m('흑백'), accent: const Color(0xFF3A3A3A), font: 'Gowun Dodum'),
  Skin(id: 'mo_line', name: '라인', category: SkinCategory.mono, bg: const [Color(0xFFFFFFFF)], frame: SkinFrame.inset, filter: _m('흑백'), accent: const Color(0xFF000000), font: 'Black Han Sans', motifs: [Motif.dottedBorder]),
];

List<Skin> skinsForCategory(SkinCategory c) =>
    kSkins.where((s) => s.category == c).toList();

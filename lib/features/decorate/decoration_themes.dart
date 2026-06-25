import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/db/app_database.dart';

/// 사진 꾸미기 테마 — 폴라로이드풍 프레임 + 캡션 + 장식 모티프.
///
/// 10종을 데이터로 정의하고 [DecoratedCard] 하나가 모든 변형을 렌더한다.
/// 결과는 RepaintBoundary로 PNG 내보내 공유한다(한글·이모지 그대로 렌더).

enum DecorMotif { none, film, washiTape, dateStamp, innerFrame, accentLine }

@immutable
class DecorTheme {
  const DecorTheme({
    required this.id,
    required this.name,
    required this.frame,
    required this.captionColor,
    this.captionFont,
    this.captionSize = 22,
    this.bottomPad = 56,
    this.sidePad = 14,
    this.radius = 10,
    this.motif = DecorMotif.none,
    this.accent = const Color(0xFFE25A7E),
    this.emoji,
  });

  final String id;
  final String name;
  final List<Color> frame; // 1색(단색) 또는 2색(그라데이션)
  final Color captionColor;
  final String? captionFont; // null = 기본 폰트
  final double captionSize;
  final double bottomPad; // 폴라로이드 느낌의 두꺼운 하단
  final double sidePad;
  final double radius;
  final DecorMotif motif;
  final Color accent;
  final String? emoji; // 캡션 뒤에 붙는 장식 이모지
}

/// 큐레이션된 10개 테마.
const List<DecorTheme> kDecorThemes = [
  DecorTheme(
    id: 'classic',
    name: '클래식',
    frame: [Color(0xFFFFFFFF)],
    captionColor: Color(0xFF4A3A44),
    captionFont: 'NanumPen',
    captionSize: 24,
  ),
  DecorTheme(
    id: 'pink',
    name: '핑크 러브',
    frame: [Color(0xFFFDE7EF), Color(0xFFF9D2E0)],
    captionColor: Color(0xFFB14A66),
    captionFont: 'NanumPen',
    captionSize: 24,
    accent: Color(0xFFE25A7E),
    emoji: '💗',
  ),
  DecorTheme(
    id: 'kraft',
    name: '크라프트',
    frame: [Color(0xFFD9C4A3)],
    captionColor: Color(0xFF5C4630),
    captionFont: 'NanumPen',
    captionSize: 24,
    motif: DecorMotif.washiTape,
    accent: Color(0xFFB89B6E),
  ),
  DecorTheme(
    id: 'film',
    name: '필름',
    frame: [Color(0xFF1C1C1E)],
    captionColor: Color(0xFFF2F2F2),
    captionSize: 14,
    bottomPad: 40,
    sidePad: 24,
    radius: 6,
    motif: DecorMotif.film,
    accent: Color(0xFFEDEDED),
  ),
  DecorTheme(
    id: 'lilac',
    name: '라일락',
    frame: [Color(0xFFEADDF7), Color(0xFFD9C7EF)],
    captionColor: Color(0xFF6B4E8F),
    captionFont: 'NanumPen',
    captionSize: 24,
    accent: Color(0xFF9B7BD0),
    emoji: '✨',
  ),
  DecorTheme(
    id: 'vintage',
    name: '빈티지',
    frame: [Color(0xFFEFE3CE)],
    captionColor: Color(0xFF6E5536),
    captionSize: 17,
    motif: DecorMotif.innerFrame,
    accent: Color(0xFF9C7B4E),
  ),
  DecorTheme(
    id: 'minimal',
    name: '미니멀',
    frame: [Color(0xFFFFFFFF)],
    captionColor: Color(0xFF8A8A8E),
    captionSize: 13,
    bottomPad: 46,
    motif: DecorMotif.accentLine,
    accent: Color(0xFF222226),
  ),
  DecorTheme(
    id: 'instant',
    name: '인스턴트',
    frame: [Color(0xFFFFFFFF)],
    captionColor: Color(0xFF4A3A44),
    captionFont: 'NanumPen',
    captionSize: 24,
    motif: DecorMotif.dateStamp,
    accent: Color(0xFFE8902E),
  ),
  DecorTheme(
    id: 'mint',
    name: '민트',
    frame: [Color(0xFFD9F0E7), Color(0xFFC4E8DA)],
    captionColor: Color(0xFF2E6B5C),
    captionFont: 'NanumPen',
    captionSize: 24,
    accent: Color(0xFF3E8E7E),
    emoji: '🌿',
  ),
  DecorTheme(
    id: 'gold',
    name: '골드 누아르',
    frame: [Color(0xFF2A2530)],
    captionColor: Color(0xFFD8B36A),
    captionSize: 18,
    motif: DecorMotif.innerFrame,
    accent: Color(0xFFD8B36A),
  ),
  DecorTheme(
    id: 'sky',
    name: '스카이',
    frame: [Color(0xFFDCECFB), Color(0xFFC5DDF5)],
    captionColor: Color(0xFF3A6EA5),
    captionFont: 'NanumPen',
    captionSize: 24,
    accent: Color(0xFF5E97D6),
    emoji: '☁️',
  ),
  DecorTheme(
    id: 'sunset',
    name: '노을',
    frame: [Color(0xFFFFE3CC), Color(0xFFFAC6C1)],
    captionColor: Color(0xFFB5562E),
    captionFont: 'NanumPen',
    captionSize: 24,
    accent: Color(0xFFE8845A),
    emoji: '🌅',
  ),
  DecorTheme(
    id: 'forest',
    name: '포레스트',
    frame: [Color(0xFFDAE7CE)],
    captionColor: Color(0xFF4A6B3A),
    captionFont: 'NanumPen',
    captionSize: 24,
    accent: Color(0xFF6E9A4E),
    emoji: '🍀',
  ),
  DecorTheme(
    id: 'mono',
    name: '모노',
    frame: [Color(0xFF222226)],
    captionColor: Color(0xFFF2F2F2),
    captionSize: 15,
    bottomPad: 46,
    motif: DecorMotif.accentLine,
    accent: Color(0xFFF2F2F2),
  ),
  DecorTheme(
    id: 'cream',
    name: '크림',
    frame: [Color(0xFFFBF3E7)],
    captionColor: Color(0xFF6E5C44),
    captionFont: 'NanumPen',
    captionSize: 24,
    accent: Color(0xFFC9A86E),
  ),
  DecorTheme(
    id: 'berry',
    name: '베리',
    frame: [Color(0xFFF3D9E8)],
    captionColor: Color(0xFF8E3B63),
    captionFont: 'NanumPen',
    captionSize: 24,
    accent: Color(0xFFC75C92),
    emoji: '🍓',
  ),
  DecorTheme(
    id: 'ocean',
    name: '오션',
    frame: [Color(0xFFCFE9EC), Color(0xFFB6DCE0)],
    captionColor: Color(0xFF2E6E73),
    captionFont: 'NanumPen',
    captionSize: 24,
    accent: Color(0xFF3E9097),
    emoji: '🌊',
  ),
  DecorTheme(
    id: 'lemon',
    name: '레몬',
    frame: [Color(0xFFFBF0C9)],
    captionColor: Color(0xFF8E711A),
    captionFont: 'NanumPen',
    captionSize: 24,
    accent: Color(0xFFE3C341),
    emoji: '🍋',
  ),
  DecorTheme(
    id: 'dusty',
    name: '더스티',
    frame: [Color(0xFFE6DCD2)],
    captionColor: Color(0xFF5C4F45),
    captionFont: 'NanumPen',
    captionSize: 22,
    motif: DecorMotif.dateStamp,
    accent: Color(0xFF8A7A6A),
  ),
  DecorTheme(
    id: 'neon',
    name: '네온',
    frame: [Color(0xFF1A1430)],
    captionColor: Color(0xFFE59BD6),
    captionSize: 16,
    bottomPad: 46,
    motif: DecorMotif.accentLine,
    accent: Color(0xFFE59BD6),
  ),
];

/// 한 장의 꾸민 사진(프레임 + 사진 + 캡션 + 모티프). 미리보기·내보내기 공용.
class DecoratedCard extends StatelessWidget {
  const DecoratedCard({
    super.key,
    required this.capture,
    required this.caption,
    required this.theme,
    this.dateText,
    this.aspect = 4 / 5,
  });

  final Capture capture;
  final String caption;
  final DecorTheme theme;
  final String? dateText; // null이면 날짜 미표시
  final double aspect;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final cap = caption.trim();
    final captionText = t.emoji == null
        ? cap
        : (cap.isEmpty ? t.emoji! : '$cap  ${t.emoji}');

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radius),
        color: t.frame.length == 1 ? t.frame.first : null,
        gradient: t.frame.length > 1
            ? LinearGradient(
                colors: t.frame,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight)
            : null,
      ),
      child: Stack(
        children: [
          Padding(
            padding:
                EdgeInsets.fromLTRB(t.sidePad, t.sidePad, t.sidePad, t.bottomPad),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: AspectRatio(
                    aspectRatio: aspect,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _photo(),
                        if (t.motif == DecorMotif.innerFrame)
                          Padding(
                            padding: const EdgeInsets.all(6),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: t.accent.withValues(alpha: 0.75),
                                    width: 1.4),
                              ),
                            ),
                          ),
                        if (t.motif == DecorMotif.dateStamp)
                          Positioned(
                            right: 8,
                            bottom: 6,
                            child: _DateStamp(
                                date: capture.capturedAt, color: t.accent),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (t.motif == DecorMotif.accentLine)
                  Container(
                    width: 34,
                    height: 3,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: t.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                if (captionText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      captionText,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: t.captionFont,
                        color: t.captionColor,
                        fontSize: t.captionSize,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                  ),
                if (dateText != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    dateText!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: t.captionFont,
                      color: t.captionColor.withValues(alpha: 0.72),
                      fontSize: t.captionSize * 0.62,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                // 캡션·날짜가 모두 비면 최소 높이 확보(빈 폴라로이드 느낌).
                if (captionText.isEmpty && dateText == null)
                  const SizedBox(height: 6),
              ],
            ),
          ),
          if (t.motif == DecorMotif.film) ...[
            Positioned(left: 5, top: 8, bottom: 8, child: _Sprockets(color: t.accent)),
            Positioned(right: 5, top: 8, bottom: 8, child: _Sprockets(color: t.accent)),
          ],
          if (t.motif == DecorMotif.washiTape) ...[
            Positioned(top: -8, left: 12, child: _Tape(color: t.accent, angle: -0.22)),
            Positioned(top: -8, right: 12, child: _Tape(color: t.accent, angle: 0.22)),
          ],
        ],
      ),
    );
  }

  Widget _photo() {
    final file = File(capture.filePath);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.cover, cacheWidth: 1080);
    }
    return const ColoredBox(color: Colors.black12);
  }
}

/// 필름 양옆 퍼포레이션(스프로킷 홀).
class _Sprockets extends StatelessWidget {
  const _Sprockets({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(
        7,
        (_) => Container(
          width: 9,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

/// 워시 테이프(반투명 사선 조각).
class _Tape extends StatelessWidget {
  const _Tape({required this.color, required this.angle});
  final Color color;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 58,
        height: 22,
        color: color.withValues(alpha: 0.5),
      ),
    );
  }
}

/// 옛 카메라 날짜 각인(주황 디지털).
class _DateStamp extends StatelessWidget {
  const _DateStamp({required this.date, required this.color});
  final DateTime date;
  final Color color;

  @override
  Widget build(BuildContext context) {
    String two(int n) => n.toString().padLeft(2, '0');
    return Text(
      "'${two(date.year % 100)} ${two(date.month)} ${two(date.day)}",
      style: TextStyle(
        fontFamily: 'monospace',
        color: color,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
        shadows: const [
          Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
    );
  }
}

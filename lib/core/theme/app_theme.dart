import 'package:flutter/material.dart';

/// 앱 전역 테마 — **토스풍**(깔끔한 블루·화이트·넉넉한 여백·또렷한 1차 액션).
///
/// 8장 원칙(iOS에서도 자연스러운 중립적 디자인) 유지: 흰 배경 + 토스 블루 포인트,
/// 굵은 한글 타이포, 둥근 카드/버튼, 색은 최소로.
class AppTheme {
  AppTheme._();

  // 토스 팔레트.
  static const Color _blue = Color(0xFF3182F6); // Toss Blue
  static const Color _ink = Color(0xFF191F28); // 본문 텍스트(거의 검정)
  static const Color _sub = Color(0xFF8B95A1); // 보조 텍스트(회색)
  static const Color _line = Color(0xFFE5E8EB); // 구분선/테두리
  static const Color _fill = Color(0xFFF2F4F6); // 옅은 회색 면(카드)

  /// 브랜드 그라데이션(아이콘·인트로·CTA) — 거의 평면에 가까운 블루.
  static const List<Color> brandGradient = [
    Color(0xFF4593FC),
    Color(0xFF3182F6),
  ];

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    var scheme = ColorScheme.fromSeed(
      seedColor: _blue,
      brightness: brightness,
    );
    if (isLight) {
      scheme = scheme.copyWith(
        primary: _blue,
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: _ink,
        onSurfaceVariant: _sub,
        outlineVariant: _line,
        surfaceContainerHighest: _fill,
        primaryContainer: const Color(0xFFE8F1FE), // 옅은 블루(완료/강조 면)
        onPrimaryContainer: _blue,
      );
    }
    final bg = scheme.surface;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: bg,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
      ),
      // 토스 스타일 1차 버튼: 블루, 둥근 14, 큼직·굵게.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          side: BorderSide(color: isLight ? _line : scheme.outlineVariant),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: DividerThemeData(
          color: isLight ? _line : scheme.outlineVariant, thickness: 1),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}

import 'package:flutter/material.dart';

/// 앱 전역 테마 — **따뜻한 연핑크 감성**(크림빛 배경·로즈 포인트·부드러운 여백).
///
/// 8장 원칙(iOS에서도 자연스러운 디자인) 유지: 차갑지 않은 크림 화이트 배경 +
/// 따뜻한 로즈핑크 포인트, 굵은 한글 타이포, 둥근 카드/버튼, 색은 절제해서.
class AppTheme {
  AppTheme._();

  // 따뜻한 파스텔(연핑크·라일락·크림) 팔레트 — 부드럽고 몽환적인 분위기.
  static const Color _rose = Color(0xFFD86A92); // 메인 포인트(부드러운 로즈, 버튼·아이콘)
  static const Color _ink = Color(0xFF4A3A44); // 본문 텍스트(웜 플럼브라운)
  static const Color _sub = Color(0xFF9B8A95); // 보조 텍스트(웜 모브그레이)
  static const Color _line = Color(0xFFEDE3EC); // 구분선/테두리(연 라일락)
  static const Color _fill = Color(0xFFF6EEF5); // 옅은 핑크-라일락 면(카드)
  static const Color _cream = Color(0xFFF8F2F7); // 웜 라일락-크림 배경(화면)

  /// 브랜드 그라데이션(아이콘·인트로·CTA) — 연핑크 → 라일락 파스텔.
  static const List<Color> brandGradient = [
    Color(0xFFF2ADC8),
    Color(0xFFC4A2E0),
  ];

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    var scheme = ColorScheme.fromSeed(
      seedColor: _rose,
      brightness: brightness,
    );
    if (isLight) {
      scheme = scheme.copyWith(
        primary: _rose,
        onPrimary: Colors.white,
        surface: _cream,
        onSurface: _ink,
        onSurfaceVariant: _sub,
        outlineVariant: _line,
        surfaceContainerHighest: _fill,
        primaryContainer: const Color(0xFFF7DCEA), // 옅은 핑크(완료/강조 면)
        onPrimaryContainer: const Color(0xFFA84E70), // 진한 로즈(위 글자색)
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
      // 1차 버튼: 로즈, 둥근 14, 큼직·굵게.
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

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

  // 디자인 토큰 — 반경 스케일(일관성).
  static const double rMd = 12;
  static const double rLg = 16;
  static const double rXl = 22;
  static const double rPill = 100;

  // 여백 스케일(4의 배수).
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s6 = 24;

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
      // ── 컴포넌트 테마(기본 Material 느낌 제거, 일관된 프리미엄 룩) ──
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rLg)),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.primary,
        secondarySelectedColor: scheme.primary,
        checkmarkColor: scheme.onPrimary,
        labelStyle: TextStyle(
            color: scheme.onSurface, fontWeight: FontWeight.w600, fontSize: 13),
        secondaryLabelStyle: TextStyle(
            color: scheme.onPrimary, fontWeight: FontWeight.w700, fontSize: 13),
        side: BorderSide(color: isLight ? _line : scheme.outlineVariant),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(rPill)),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.primary.withValues(alpha: 0.18),
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
        trackHeight: 4,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? scheme.onPrimary : null),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? scheme.primary : null),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rLg)),
        titleTextStyle: TextStyle(
            color: scheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w800),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _ink,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rMd)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(rXl)),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle:
            const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(rMd)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(rPill)),
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}

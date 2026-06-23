import 'package:flutter/material.dart';

/// 앱 전역 테마.
///
/// 8장 원칙: iOS에서도 자연스러운 **중립적 디자인**. Material 위젯 남용을 피하고
/// 가족 사진 앱 정서에 맞는 따뜻하고 차분한 팔레트를 사용한다.
class AppTheme {
  AppTheme._();

  /// 브랜드 시드 컬러 — 따뜻한 테라코타 톤(가족·온기).
  static const Color _seed = Color(0xFFE07A5F);

  /// 따뜻한 크림 배경(라이트) — 기본 M3 회색빛 surface 대신 밝고 포근하게.
  static const Color _cream = Color(0xFFFFF8F3);

  /// 브랜드 그라데이션(아이콘·인트로·CTA에 일관 사용).
  static const List<Color> brandGradient = [
    Color(0xFFEE9B82),
    Color(0xFFD25E49),
  ];

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    var scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    // 라이트에서 표면을 크림으로 끌어올려 전체 톤을 밝고 따뜻하게.
    if (isLight) scheme = scheme.copyWith(surface: _cream);
    final bg = scheme.surface;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: bg,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      // 중립적이고 가벼운 폰트 굵기 — iOS에서도 이질감 없게.
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}

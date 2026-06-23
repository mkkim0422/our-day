import 'package:flutter/material.dart';

/// 앱 전역 테마.
///
/// 8장 원칙: iOS에서도 자연스러운 **중립적 디자인**. Material 위젯 남용을 피하고
/// 가족 사진 앱 정서에 맞는 따뜻하고 차분한 팔레트를 사용한다.
class AppTheme {
  AppTheme._();

  /// 브랜드 시드 컬러 — 따뜻한 테라코타 톤(가족·온기).
  static const Color _seed = Color(0xFFE07A5F);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      // 중립적이고 가벼운 폰트 굵기 — iOS에서도 이질감 없게.
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}

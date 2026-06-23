import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/intro/intro_screen.dart';

/// 앱 루트 위젯.
///
/// 첫 화면은 [IntroScreen](브랜드 인트로). 인트로가 끝나면 RootScreen으로 전환돼
/// 프로젝트 유무에 따라 온보딩(①)/홈(②)으로 분기한다.
class OurDayApp extends StatelessWidget {
  const OurDayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '그날 우리',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const IntroScreen(),
    );
  }
}

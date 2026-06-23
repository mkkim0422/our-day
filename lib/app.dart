import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/root_screen.dart';

/// 앱 루트 위젯.
///
/// 진입점은 [RootScreen]이 프로젝트 유무에 따라 온보딩(①)/홈(②)으로 분기한다.
/// 개별 화면 전환은 Navigator 기반(촬영 흐름과 동일 패턴, 작업 #4).
class OurDayApp extends StatelessWidget {
  const OurDayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '그날 우리',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const RootScreen(),
    );
  }
}

import 'package:flutter/material.dart';

import '../../branding/app_logo.dart';
import '../root_screen.dart';

/// 첫 진입 인트로(스플래시) — 브랜드 로고가 떠오르고 슬로건이 이어진 뒤 홈으로 전환.
///
/// 콜드스타트 네이티브 런치 배경(테라코타)과 이어지도록 같은 그라데이션을 쓴다.
/// 화면을 탭하면 즉시 건너뛴다.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..forward();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) _go();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _go() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, _, _) => const RootScreen(),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  // 구간별 커브.
  Animation<double> _interval(double begin, double end, Curve curve) =>
      CurvedAnimation(parent: _c, curve: Interval(begin, end, curve: curve));

  @override
  Widget build(BuildContext context) {
    final logoScale = _interval(0.0, 0.45, Curves.easeOutBack);
    final logoFade = _interval(0.0, 0.32, Curves.easeOut);
    final titleAnim = _interval(0.32, 0.62, Curves.easeOut);
    final sloganAnim = _interval(0.55, 0.82, Curves.easeOut);
    final screenFade = _interval(0.9, 1.0, Curves.easeIn);

    return GestureDetector(
      onTap: _go, // 탭하면 건너뛰기.
      child: Scaffold(
        body: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            return Opacity(
              opacity: 1 - screenFade.value,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF4593FC), Color(0xFF3182F6)],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),
                    Opacity(
                      opacity: logoFade.value,
                      child: Transform.scale(
                        scale: 0.6 + 0.4 * logoScale.value,
                        child: const AppLogoMark(size: 132),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _fadeSlide(
                      titleAnim,
                      child: const Text(
                        '그날 우리',
                        style: TextStyle(
                          color: Color(0xFFFFF4EC),
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _fadeSlide(
                      sloganAnim,
                      child: Text(
                        '매달 한 컷, 그날의 우리',
                        style: TextStyle(
                          color: const Color(0xFFFFF4EC).withValues(alpha: 0.9),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(flex: 4),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _fadeSlide(Animation<double> anim, {required Widget child}) {
    return Opacity(
      opacity: anim.value,
      child: Transform.translate(
        offset: Offset(0, 12 * (1 - anim.value)),
        child: child,
      ),
    );
  }
}

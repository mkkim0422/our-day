import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home/home_providers.dart';
import 'home/home_screen.dart';
import 'onboarding/new_project_screen.dart';

/// 앱 루트 게이트.
///
/// 프로젝트가 하나도 없으면 환영/온보딩(①)으로, 있으면 가장 최근 프로젝트의
/// 홈/타임라인(②)으로 보낸다. 라우팅은 Navigator 기반(촬영 흐름과 동일 패턴).
class RootScreen extends ConsumerWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsProvider);

    return projectsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('시작 중 오류: $e')),
      ),
      data: (projects) {
        if (projects.isEmpty) return const _WelcomeScreen();
        // MVP는 단일 사용자 — 가장 최근 프로젝트를 홈으로(전환 UI는 v1.5).
        return HomeScreen(project: projects.first);
      },
    );
  }
}

/// 첫 실행 환영 화면 — 30초 내 첫 프로젝트 생성 유도(3장).
class _WelcomeScreen extends StatelessWidget {
  const _WelcomeScreen();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.camera_outlined, size: 72, color: scheme.primary),
              const SizedBox(height: 20),
              Text('그날 우리', textAlign: TextAlign.center, style: text.headlineMedium),
              const SizedBox(height: 8),
              Text(
                '같은 포즈로 매달 한 컷.\n시간이 쌓이면 가족의 변화가 보입니다.',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NewProjectScreen()),
                ),
                child: const Text('시작하기'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

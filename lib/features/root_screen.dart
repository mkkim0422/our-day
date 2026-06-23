import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/providers.dart';
import '../services/notifications/notification_service.dart';
import '../services/providers.dart';
import 'capture/capture_screen.dart';
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
    // 알림 탭(②-1 입력경로 4) → 해당 프로젝트의 촬영 화면으로 진입.
    ref.listen<NotificationPayload?>(pendingNotificationProvider, (_, next) {
      if (next == null) return;
      ref.read(pendingNotificationProvider.notifier).clear();
      _openFromNotification(context, ref, next);
    });

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

  /// 알림 페이로드로 촬영 화면 진입. captureId가 있으면(회상 알림) 그 사진을
  /// 오버레이 기준으로, 없으면 가장 최근 사진을 기준으로 띄운다(4·5장).
  Future<void> _openFromNotification(
    BuildContext context,
    WidgetRef ref,
    NotificationPayload payload,
  ) async {
    final project =
        await ref.read(projectRepositoryProvider).getById(payload.projectId);
    if (project == null || !context.mounted) return;

    final captureRepo = ref.read(captureRepositoryProvider);
    final reference = payload.captureId != null
        ? await captureRepo.getById(payload.captureId!)
        : await captureRepo.latestForProject(project.id);
    if (!context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CaptureScreen(
          project: project,
          referenceCapture: reference,
          placeId: reference?.placeId,
        ),
      ),
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

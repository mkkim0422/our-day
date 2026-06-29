import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../branding/app_logo.dart';
import '../core/theme/app_theme.dart';
import '../data/db/app_database.dart';
import '../data/repositories/providers.dart';
import '../services/location/place_recall.dart';
import '../services/notifications/notification_service.dart';
import '../services/providers.dart';
import '../services/sample/sample_seeder.dart';
import 'capture/capture_detail_screen.dart';
import 'capture/capture_screen.dart';
import 'compare/compare_screen.dart';
import 'home/album_hub_screen.dart';
import 'home/home_providers.dart';
import 'home/project_shell.dart';
import 'intro/sample_showcase_screen.dart';
import 'onboarding/new_project_screen.dart';

/// 앱 루트 게이트.
///
/// 프로젝트가 하나도 없으면 환영/온보딩(①)으로, 있으면 가장 최근 프로젝트의
/// 홈/타임라인(②)으로 보낸다. 또한 앱 시작/복귀 시 **위치 기반 회상 알림**의
/// 전경 근접 체크를 수행한다(5장).
class RootScreen extends ConsumerStatefulWidget {
  const RootScreen({super.key});

  @override
  ConsumerState<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends ConsumerState<RootScreen>
    with WidgetsBindingObserver {
  bool _seeding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 콜드스타트 알림 탭은 RootScreen 구독 전에 set되어 build의 listen이 놓치므로,
      // 마운트 직후 현재 페이로드를 직접 한 번 소비한다.
      _initFirstLaunch();
      _consumePendingNotification();
      _checkPlaceRecall();
    });
  }

  /// 첫 실행 처리 — 프로젝트가 없으면 온보딩 샘플(가족 5컷)을 심는다.
  /// 이미 자기 기록이 있는 사용자는 샘플을 건너뛴다(쇼케이스도 생략).
  Future<void> _initFirstLaunch() async {
    try {
      final settings = await ref.read(appSettingsProvider.future);
      if (settings.sampleSeeded) return;

      final projects = await ref.read(projectsProvider.future);
      final notifier = ref.read(appSettingsProvider.notifier);
      if (projects.isNotEmpty) {
        await notifier.markSampleSeeded();
        await notifier.markShowcaseSeen();
        return;
      }

      if (mounted) setState(() => _seeding = true);
      try {
        await ref.read(sampleSeederProvider).seed();
      } finally {
        await notifier.markSampleSeeded();
        if (mounted) setState(() => _seeding = false);
      }
    } catch (_) {
      // 샘플 시드는 best-effort — 실패해도 앱 진입은 막지 않는다.
      if (mounted) setState(() => _seeding = false);
    }
  }

  Future<void> _consumePendingNotification() async {
    final payload = ref.read(pendingNotificationProvider);
    if (payload == null) return;
    ref.read(pendingNotificationProvider.notifier).clear();
    await _openFromNotification(context, payload);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 같은 장소에 다시 와서 앱을 열면 그때 사진으로 회상 알림(5장).
    // (진짜 배경 지오펜스는 후속 — 동일한 PlaceRecall 로직을 재사용.)
    if (state == AppLifecycleState.resumed) _checkPlaceRecall();
  }

  /// opt-in이면 현재 위치를 읽어 반경 내 추억 장소가 있으면 회상 알림을 띄운다.
  /// 빈도 제한(쿨다운)은 [PlaceRecall]과 저장된 마지막 알림 시각으로 처리.
  Future<void> _checkPlaceRecall() async {
    try {
      // 첫 프레임엔 설정/프로젝트가 아직 loading일 수 있으므로 값을 await(콜드스타트
      // "막 그 장소에 도착해 앱을 연" 케이스에서도 동작하도록).
      final settings = await ref.read(appSettingsProvider.future);
      if (!settings.locationRecallEnabled) return;

      final projects = await ref.read(projectsProvider.future);
      if (projects.isEmpty) return;
      final project = projects.first;

      final point = await ref.read(locationServiceProvider).current();
      if (point == null) return;

      final places = await ref
          .read(placeRepositoryProvider)
          .watchByProject(project.id)
          .first;
      final now = DateTime.now();
      final match = PlaceRecall.match(
        here: point,
        places: places,
        lastNotified: settings.placeLastNotified,
        now: now,
      );
      if (match == null) return;

      final latest =
          await ref.read(captureRepositoryProvider).latestForPlace(match.id);
      if (latest == null) return;

      await ref.read(notificationServiceProvider).showPlaceRecall(
            place: match,
            latest: latest,
            projectId: project.id,
          );
      await ref
          .read(appSettingsProvider.notifier)
          .recordPlaceNotified(match.id, now);
    } catch (_) {
      // 위치 회상은 best-effort — 권한/위치/플러그인 실패 시 조용히 건너뜀.
    }
  }

  @override
  Widget build(BuildContext context) {
    // 알림 탭(②-1 입력경로 4) → 해당 프로젝트의 촬영 화면으로 진입.
    ref.listen<NotificationPayload?>(pendingNotificationProvider, (_, next) {
      if (next == null) return;
      ref.read(pendingNotificationProvider.notifier).clear();
      _openFromNotification(context, next);
    });

    final projectsAsync = ref.watch(projectsProvider);
    final settings = ref.watch(appSettingsProvider).value;

    if (_seeding) return _loading();

    return projectsAsync.when(
      loading: _loading,
      error: (e, _) => Scaffold(
        body: Center(child: Text('시작 중 오류: $e')),
      ),
      data: (projects) {
        // 첫 실행 처리(시드) 진행 중이면 깜빡임 방지 스피너.
        if (settings == null || !settings.sampleSeeded) return _loading();
        // 시드된 샘플 타임랩스 쇼케이스(최초 1회).
        if (!settings.showcaseSeen && projects.isNotEmpty) {
          return SampleShowcaseScreen(project: projects.first);
        }
        if (projects.isEmpty) return const _WelcomeScreen();
        // 프로젝트 선택/전환은 앨범 허브가 담당(갤러리식 카드 그리드).
        // 카드 탭 → ProjectShell(홈/타임라인/비교 상단 탭)로 진입.
        return const AlbumHubScreen();
      },
    );
  }

  Widget _loading() => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );

  /// 알림 페이로드로 촬영 화면 진입. captureId가 있으면(회상 알림) 그 사진을
  /// 오버레이 기준으로, 없으면 가장 최근 사진을 기준으로 띄운다(4·5장).
  Future<void> _openFromNotification(
    BuildContext context,
    NotificationPayload payload,
  ) async {
    final project =
        await ref.read(projectRepositoryProvider).getById(payload.projectId);
    if (project == null || !context.mounted) return;

    // 연말 리캡 알림 → 비교·타임랩스 화면(아이디어6).
    if (payload.recap) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CompareScreen(project: project)),
      );
      return;
    }

    final captureRepo = ref.read(captureRepositoryProvider);
    final reference = payload.captureId != null
        ? await captureRepo.getById(payload.captureId!)
        : await captureRepo.latestForProject(project.id);
    if (!context.mounted) return;

    // 회상 알림(기념일·장소) → 그 추억 사진을 먼저 보여준다(감정 환기).
    // 거기서 "같은 구도로 한 컷"을 누르면 그 사진을 오버레이 기준으로 촬영.
    if (payload.recall && reference != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              CaptureDetailScreen(project: project, capture: reference),
        ),
      );
      return;
    }

    // 그 외(주기·이벤트 페그 알림) → 곧장 촬영 화면.
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

/// 첫 실행 환영 화면 — 30초 내 첫 기록 생성 유도(3장).
class _WelcomeScreen extends ConsumerWidget {
  const _WelcomeScreen();

  /// 첫 기록 생성 → 곧바로 **그 기록 안(ProjectShell)으로 진입**(허브로 떨구지 않음).
  /// 뒤로가기 시 허브(RootScreen이 이미 허브로 재빌드됨)로 자연스럽게 복귀.
  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final created = await Navigator.of(context).push<Project>(
      MaterialPageRoute(builder: (_) => const NewProjectScreen()),
    );
    if (created == null || !context.mounted) return;
    ref.read(selectedProjectIdProvider.notifier).select(created.id);
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProjectShell(project: created)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              // 브랜드 로고 배지(그라데이션 원 + 카메라·하트).
              Center(
                child: Container(
                  width: 116,
                  height: 116,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: AppTheme.brandGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Center(child: AppLogoMark(size: 78)),
                ),
              ),
              const SizedBox(height: 24),
              Text('그날 우리', textAlign: TextAlign.center, style: text.headlineMedium),
              const SizedBox(height: 8),
              Text(
                '같은 포즈로 매달 한 컷.\n차곡차곡, 우리만의 이야기가 쌓여요.',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: () => _start(context, ref),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../capture/backfill_screen.dart';
import '../capture/capture_screen.dart';
import '../compare/compare_screen.dart';
import '../settings/settings_screen.dart';
import 'album_tab.dart';
import 'home_providers.dart';
import 'home_screen.dart';

/// 프로젝트 진입 셸 — 앨범 허브에서 카드를 탭하면 들어오는 화면.
///
/// 갤러리 앱 멘탈 모델: 허브에서 "앨범(프로젝트)"을 고르고 → 그 안에서 본다.
/// 상단 탭(홈/타임라인/비교) + 촬영 FAB + 설정·백필. 뒤로가기로 허브 복귀.
/// (이전 [MainShell]의 하단 네비 + 프로젝트 칩 줄을 대체.)
class ProjectShell extends ConsumerStatefulWidget {
  const ProjectShell({super.key, required this.project});

  final Project project;

  @override
  ConsumerState<ProjectShell> createState() => _ProjectShellState();
}

class _ProjectShellState extends ConsumerState<ProjectShell>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this)
    ..addListener(() => setState(() {})); // FAB/액션 노출이 탭에 따라 달라짐.

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 허브에서 받은 project를 기준으로, 제목 등 최신값은 provider로 갱신.
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final project = projects.firstWhere(
      (p) => p.id == widget.project.id,
      orElse: () => widget.project,
    );
    // 홈 탭은 CTA 카드가 단일 촬영 버튼이라 FAB를 두지 않는다(중복 제거).
    // 타임라인 탭에만 촬영 FAB를 노출, 비교 탭은 없음.
    final showFab = _tab.index == 1;
    final onCompare = _tab.index == 2;

    return Scaffold(
      appBar: AppBar(
        title: Text(project.title),
        actions: [
          if (!onCompare)
            IconButton(
              icon: const Icon(Icons.library_add_outlined),
              tooltip: '예전 사진 채우기',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => BackfillScreen(project: project)),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '설정',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => SettingsScreen(project: project)),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: '홈'),
            Tab(text: '타임라인'),
            Tab(text: '비교'),
          ],
        ),
      ),
      // 비교 화면은 좌우 드래그(스크러버)를 쓰므로 탭 스와이프와 충돌 방지 위해
      // 스와이프 전환을 끄고 탭 탭으로만 이동.
      body: TabBarView(
        controller: _tab,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          HomeTab(project: project),
          AlbumTab(project: project),
          CompareView(project: project),
        ],
      ),
      floatingActionButton: !showFab
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openCapture(project),
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('촬영'),
            ),
    );
  }

  Future<void> _openCapture(Project project) async {
    final caps = ref.read(capturesProvider(project.id)).value ?? const [];
    final latest = caps.isNotEmpty ? caps.first : null;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CaptureScreen(project: project, referenceCapture: latest),
      ),
    );
  }
}

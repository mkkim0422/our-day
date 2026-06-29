import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../capture/backfill_screen.dart';
import '../capture/capture_screen.dart';
import '../compare/compare_screen.dart';
import '../settings/album_settings_screen.dart';
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
  // 2탭으로 단순화: 앨범(촬영 CTA + 진척 + 전체 기록) / 추억(타임랩스·비교).
  late final TabController _tab = TabController(length: 2, vsync: this)
    ..addListener(() => setState(() {}));

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
    return Scaffold(
      appBar: AppBar(
        title: Text(project.title),
        actions: [
          // 아이콘만 있으면 부모가 뜻을 모름 → 글자 라벨이 있는 메뉴(⋮)로.
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: '메뉴',
            onSelected: (v) {
              if (v == 'backfill') {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => BackfillScreen(project: project)));
              } else if (v == 'settings') {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AlbumSettingsScreen(project: project)));
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'backfill',
                child: ListTile(
                  leading: Icon(Icons.library_add_outlined),
                  title: Text('예전 사진 채우기'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings_outlined),
                  title: Text('앨범 설정'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(icon: Icon(Icons.photo_library_outlined), text: '앨범'),
            // '추억'(모호)/'변화 보기'(딱딱함) → '다시보기'(친숙·타임랩스/비교 보상).
            Tab(icon: Icon(Icons.play_circle_outline), text: '다시보기'),
          ],
        ),
      ),
      // 비교(추억) 화면은 좌우 드래그를 쓰므로 탭 스와이프 비활성.
      body: TabBarView(
        controller: _tab,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          HomeTab(project: project),
          CompareView(project: project),
        ],
      ),
      // 1차 액션(촬영)은 어느 탭에서도 항상 보이게.
      floatingActionButton: FloatingActionButton.extended(
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

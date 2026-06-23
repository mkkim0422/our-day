import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../capture/backfill_screen.dart';
import '../capture/capture_screen.dart';
import '../compare/compare_screen.dart';
import '../onboarding/new_project_screen.dart';
import '../settings/settings_screen.dart';
import 'album_tab.dart';
import 'home_providers.dart';
import 'home_screen.dart';

/// 메인 셸 — 하단 네비(홈/앨범/비교) + 상단 프로젝트 셀렉터 + 촬영 FAB.
///
/// 프로젝트 추가/전환을 항상 보이는 칩 줄로 노출(이전 제목-탭 시트 대체).
/// 비교·타임랩스는 본문 [CompareView]를 탭으로 임베드한다.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _tab = 0;

  static const _titles = ['그날 우리', '앨범', '비교 · 타임랩스'];

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    if (projects.isEmpty) {
      // RootScreen이 빈 경우를 막지만 안전망.
      return const Scaffold(body: SizedBox.shrink());
    }
    final selectedId = ref.watch(selectedProjectIdProvider);
    final project = projects.firstWhere(
      (p) => p.id == selectedId,
      orElse: () => projects.first,
    );

    final tabs = [
      HomeTab(project: project),
      AlbumTab(project: project),
      CompareView(project: project),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_tab == 0 ? project.title : _titles[_tab]),
        actions: [
          if (_tab != 2)
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
      ),
      body: Column(
        children: [
          _ProjectSelector(projects: projects, currentId: project.id),
          const Divider(height: 1),
          Expanded(child: IndexedStack(index: _tab, children: tabs)),
        ],
      ),
      floatingActionButton: _tab == 2
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openCapture(project),
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('촬영'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: '홈'),
          NavigationDestination(
              icon: Icon(Icons.photo_library_outlined),
              selectedIcon: Icon(Icons.photo_library),
              label: '앨범'),
          NavigationDestination(
              icon: Icon(Icons.auto_awesome_motion_outlined),
              selectedIcon: Icon(Icons.auto_awesome_motion),
              label: '비교'),
        ],
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

/// 프로젝트 칩 셀렉터 — 전환 + 새 프로젝트 만들기(항상 노출).
class _ProjectSelector extends ConsumerWidget {
  const _ProjectSelector({required this.projects, required this.currentId});

  final List<Project> projects;
  final String currentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          for (final p in projects)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(p.title),
                selected: p.id == currentId,
                onSelected: (_) =>
                    ref.read(selectedProjectIdProvider.notifier).select(p.id),
              ),
            ),
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('새 프로젝트'),
            onPressed: () => _createProject(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _createProject(BuildContext context, WidgetRef ref) async {
    final created = await Navigator.of(context).push<Project>(
      MaterialPageRoute(builder: (_) => const NewProjectScreen()),
    );
    if (created != null) {
      ref.read(selectedProjectIdProvider.notifier).select(created.id);
    }
  }
}

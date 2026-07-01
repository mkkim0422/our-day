import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../capture/backfill_screen.dart';
import '../capture/capture_screen.dart';
import '../settings/album_settings_screen.dart';
import 'home_providers.dart';
import 'home_screen.dart';

/// 프로젝트 진입 셸 — 앨범 허브에서 카드를 탭하면 들어오는 화면.
///
/// 한 화면(앨범)으로 통합: 같은 사진을 "정지(그리드)"와 "변화 영상(타임랩스·비교
/// ·성장 스토리)"으로 따로 탭을 오가지 않도록, 앨범 안에서 '▶ 변화 영상 보기'로
/// 들어간다. 촬영 FAB + ⋮(예전 사진·설정). 뒤로가기로 허브 복귀.
class ProjectShell extends ConsumerWidget {
  const ProjectShell({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 허브에서 받은 project를 기준으로, 제목 등 최신값은 provider로 갱신.
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final current = projects.firstWhere(
      (p) => p.id == project.id,
      orElse: () => project,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(current.title),
        actions: [
          // 아이콘만 있으면 부모가 뜻을 모름 → 글자 라벨이 있는 메뉴(⋮)로.
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: '메뉴',
            onSelected: (v) {
              if (v == 'backfill') {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => BackfillScreen(project: current)));
              } else if (v == 'settings') {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AlbumSettingsScreen(project: current)));
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
      ),
      body: HomeTab(project: current),
      // 1차 액션(촬영)은 항상 보이게.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCapture(context, ref, current),
        icon: const Icon(Icons.camera_alt_rounded),
        label: const Text('촬영'),
      ),
    );
  }

  Future<void> _openCapture(
      BuildContext context, WidgetRef ref, Project project) async {
    final caps = ref.read(capturesProvider(project.id)).value ?? const [];
    // 겹쳐 보기 기준 = 가장 최근에 찍은 날짜의 컷(표시 순서와 무관).
    final latest = caps.isEmpty
        ? null
        : caps.reduce((a, b) => a.capturedAt.isAfter(b.capturedAt) ? a : b);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CaptureScreen(project: project, referenceCapture: latest),
      ),
    );
  }
}

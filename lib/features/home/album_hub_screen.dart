import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/db/app_database.dart';
import '../onboarding/new_project_screen.dart';
import 'home_providers.dart';
import 'project_shell.dart';

/// 앨범 허브 — 모든 프로젝트를 카드 그리드로 보여주는 최상위 화면(갤러리식).
///
/// 가장 최근 프로젝트는 큰 히어로 카드("이어서 보기"), 나머지는 2열 그리드 +
/// "새 프로젝트" 추가 타일. 카드 탭 → 그 프로젝트 안([ProjectShell])으로 진입.
/// 빈 프로젝트(0컷)·커버 없는 경우도 브랜드 플레이스홀더로 안전하게 표시한다.
class AlbumHubScreen extends ConsumerWidget {
  const AlbumHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    // projects가 빈 경우는 RootScreen이 환영 화면으로 처리하지만 안전망.
    if (projects.isEmpty) return _HubEmpty(onCreate: () => _create(context, ref));

    final hero = projects.first;
    final rest = projects.skip(1).toList();
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('그날 우리')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Text('이어서 보기',
              style: text.titleSmall?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          _HeroProjectCard(
            project: hero,
            onTap: () => _open(context, ref, hero),
          ),
          const SizedBox(height: 24),
          Text('모든 기록', style: text.titleMedium),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.82,
            children: [
              for (final p in rest)
                _ProjectGridCard(
                  project: p,
                  onTap: () => _open(context, ref, p),
                ),
              _AddProjectTile(onTap: () => _create(context, ref)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref, Project p) async {
    ref.read(selectedProjectIdProvider.notifier).select(p.id);
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProjectShell(project: p)),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final created = await Navigator.of(context).push<Project>(
      MaterialPageRoute(builder: (_) => const NewProjectScreen()),
    );
    if (created != null && context.mounted) {
      ref.read(selectedProjectIdProvider.notifier).select(created.id);
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProjectShell(project: created)),
      );
    }
  }
}

/// 프로젝트 커버 썸네일 경로 — coverPhotoId 우선, 없으면 가장 최근 컷.
/// 사진이 하나도 없으면 null(→ 브랜드 플레이스홀더).
String? _coverPath(Project project, List<Capture> caps) {
  if (caps.isEmpty) return null;
  final coverId = project.coverPhotoId;
  if (coverId != null) {
    for (final c in caps) {
      if (c.id == coverId) return c.thumbPath;
    }
  }
  return caps.first.thumbPath;
}

/// 대표(최근) 프로젝트 히어로 카드 — 와이드 커버 + 하단 그라데이션 라벨.
class _HeroProjectCard extends ConsumerWidget {
  const _HeroProjectCard({required this.project, required this.onTap});

  final Project project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref.watch(capturesProvider(project.id)).value ?? const [];
    final cover = _coverPath(project, caps);
    final count = caps.length;
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(22);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: ClipRRect(
          borderRadius: radius,
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _CoverImage(path: cover),
                // 라벨 가독성용 하단 그라데이션.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black54],
                      stops: [0.45, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleLarge?.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        count == 0 ? '아직 사진이 없어요 · 첫 컷을 남겨요' : '$count컷',
                        style: text.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.92)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 2열 그리드 카드 — 정사각 커버 + 제목 + 장수.
class _ProjectGridCard extends ConsumerWidget {
  const _ProjectGridCard({required this.project, required this.onTap});

  final Project project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref.watch(capturesProvider(project.id)).value ?? const [];
    final cover = _coverPath(project, caps);
    final count = caps.length;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _CoverImage(path: cover),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              project.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              count == 0 ? '0컷 · 첫 컷을 남겨요' : '$count컷',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// 커버 이미지 — 파일이 있으면 표시, 없으면(빈 프로젝트/유실) 브랜드 플레이스홀더.
class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final p = path;
    if (p != null) {
      final file = File(p);
      if (file.existsSync()) return Image.file(file, fit: BoxFit.cover);
    }
    return const _PlaceholderCover();
  }
}

class _PlaceholderCover extends StatelessWidget {
  const _PlaceholderCover();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppTheme.brandGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(Icons.photo_camera_outlined, color: Colors.white, size: 38),
      ),
    );
  }
}

/// "새 기록" 추가 타일(그리드 마지막 칸).
///
/// 프로젝트 카드와 동일한 Column 구조(정사각 영역 + 제목/부제 2줄)로 맞춰
/// 사진 영역·제목 줄이 옆 카드와 정확히 정렬되도록 한다(#5 틀어짐 수정).
class _AddProjectTile extends StatelessWidget {
  const _AddProjectTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant),
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              ),
              child: Center(
                child: Icon(Icons.add_rounded, size: 34, color: scheme.primary),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('새 기록',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700, color: scheme.primary)),
          Text('추가하기',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// 안전망 빈 화면(정상 흐름에선 RootScreen 환영 화면이 처리).
class _HubEmpty extends StatelessWidget {
  const _HubEmpty({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('그날 우리')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_album_outlined,
                size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('아직 기록이 없어요',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('새 기록 만들기'),
            ),
          ],
        ),
      ),
    );
  }
}

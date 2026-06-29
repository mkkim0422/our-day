import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/db/app_database.dart';
import '../compare/widgets/timelapse_player.dart';
import 'growth_story.dart';

/// 성장 스토리 1개를 펼쳐 보는 화면 — 타임랩스 재생 + 사진 그리드.
/// (BGM·영상 내보내기는 후속. 우선 보기/검증.)
class GrowthStoryViewScreen extends StatelessWidget {
  const GrowthStoryViewScreen({super.key, required this.story});

  final GrowthStory story;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(story.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(story.subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          if (story.captures.length >= 2)
            TimelapsePlayer(framesAsc: story.captures)
          else
            _single(story.captures.first),
          const SizedBox(height: 20),
          Text('이 스토리의 사진',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: story.captures.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, i) => _thumb(context, story.captures[i]),
          ),
        ],
      ),
    );
  }

  Widget _single(Capture c) {
    final file = File(c.decoratedPath ?? c.filePath);
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: file.existsSync()
            ? Image.file(file, fit: BoxFit.cover)
            : const ColoredBox(color: Colors.black12),
      ),
    );
  }

  Widget _thumb(BuildContext context, Capture c) {
    final file = File(c.decoratedPath ?? c.thumbPath);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: file.existsSync()
          ? Image.file(file, fit: BoxFit.cover)
          : ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest),
    );
  }
}

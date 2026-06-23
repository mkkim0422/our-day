import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/repositories/providers.dart';
import '../../services/providers.dart';
import '../compare/compare_screen.dart';

/// 사진 상세 — 썸네일 탭 시 **풀사이즈**로 보여준다(명세 ② "썸네일 탭 → 상세").
///
/// 핀치 줌(원본 고해상도 확인), 공유(⑥), 삭제, 비교·타임랩스(⑤) 진입을 제공.
/// 원본은 인쇄 품질로 보존돼 있으므로(7-1장) 여기서 원본 경로를 그대로 띄운다.
class CaptureDetailScreen extends ConsumerWidget {
  const CaptureDetailScreen({
    super.key,
    required this.project,
    required this.capture,
  });

  final Project project;
  final Capture capture;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = File(capture.filePath);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(capture.periodLabel),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: '공유',
            onPressed: () => _share(ref),
          ),
          PopupMenuButton<String>(
            color: Colors.grey[900],
            onSelected: (v) {
              if (v == 'delete') _confirmDelete(context, ref);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'delete',
                child: Text('삭제', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 풀사이즈 + 핀치 줌. 원본 파일이 없으면 안내(깨짐 방지).
          Expanded(
            child: file.existsSync()
                ? InteractiveViewer(
                    maxScale: 5,
                    child: Center(child: Image.file(file)),
                  )
                : const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_outlined,
                            color: Colors.white54, size: 56),
                        SizedBox(height: 12),
                        Text('원본 파일을 찾을 수 없어요',
                            style: TextStyle(color: Colors.white54)),
                      ],
                    ),
                  ),
          ),
          _infoBar(context),
        ],
      ),
    );
  }

  Widget _infoBar(BuildContext context) {
    final note = capture.note;
    return Container(
      width: double.infinity,
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatDate(capture.capturedAt),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(note, style: const TextStyle(color: Colors.white)),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.auto_awesome_motion_outlined),
            label: const Text('비교 · 타임랩스 보기'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CompareScreen(project: project),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _share(WidgetRef ref) async {
    await ref.read(shareServiceProvider).shareFiles(
      [capture.filePath],
      text: '그날 우리 · ${capture.periodLabel}',
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이 사진을 삭제할까요?'),
        content: const Text('타임라인에서 사라지고 되돌릴 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final captureRepo = ref.read(captureRepositoryProvider);
    await ref
        .read(photoStorageProvider)
        .deleteFiles(capture.filePath, capture.thumbPath);
    await captureRepo.delete(capture.id);

    // 삭제로 회상 알림 대상이 바뀌므로 재예약(작업 #5 패턴과 동일).
    final remaining = await captureRepo.listByProject(project.id);
    await ref
        .read(notificationServiceProvider)
        .scheduleForProject(project, remaining);

    if (context.mounted) Navigator.of(context).pop();
  }

  String _formatDate(DateTime d) =>
      '${d.year}년 ${d.month}월 ${d.day}일';
}

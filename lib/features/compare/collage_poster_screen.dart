import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/db/app_database.dart';
import '../../services/providers.dart';
import '../home/home_providers.dart';

/// 아이디어4 — 성장 포스터/콜라주.
///
/// 프로젝트의 모든 컷을 한 장의 격자 포스터로 묶어 이미지로 내보낸다(인쇄·SNS).
/// 한글 라벨·워터마크를 Flutter 렌더 그대로 캡처(RepaintBoundary→PNG).
class CollagePosterScreen extends ConsumerStatefulWidget {
  const CollagePosterScreen({super.key, required this.project});

  final Project project;

  @override
  ConsumerState<CollagePosterScreen> createState() =>
      _CollagePosterScreenState();
}

class _CollagePosterScreenState extends ConsumerState<CollagePosterScreen> {
  final _posterKey = GlobalKey();
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final capturesAsync = ref.watch(capturesProvider(widget.project.id));

    return Scaffold(
      appBar: AppBar(title: const Text('성장 포스터')),
      body: capturesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오기 오류: $e')),
        data: (captures) {
          if (captures.isEmpty) {
            return const Center(child: Text('사진이 쌓이면 포스터를 만들 수 있어요.'));
          }
          // 시간순(오래된→최근)으로 배치.
          final asc = captures.reversed.toList(growable: false);
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: RepaintBoundary(
                    key: _posterKey,
                    child: _Poster(title: widget.project.title, captures: asc),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52)),
                        onPressed: _exporting ? null : _share,
                        icon: _exporting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.ios_share),
                        label: Text(_exporting ? '만드는 중…' : '포스터 이미지로 공유'),
                      ),
                      const SizedBox(height: 8),
                      // 공유와 별개로 내 사진첩에 바로 보관(⑦).
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48)),
                        onPressed: _exporting ? null : _saveToGallery,
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('기기에 저장'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _share() async {
    setState(() => _exporting = true);
    try {
      final share = ref.read(shareServiceProvider);
      final path = await share.captureBoundaryToPng(_posterKey, pixelRatio: 3);
      await share.shareFiles([path], text: '그날 우리 — ${widget.project.title} 성장 포스터');
    } catch (e) {
      _snack('포스터 공유 실패: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// 포스터를 기기 사진첩에 저장(⑦).
  Future<void> _saveToGallery() async {
    setState(() => _exporting = true);
    try {
      final share = ref.read(shareServiceProvider);
      final path = await share.captureBoundaryToPng(_posterKey, pixelRatio: 3);
      await share.saveToGallery(path);
      _snack('포스터를 사진첩에 저장했어요.');
    } catch (e) {
      _snack('포스터 저장 실패: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.title, required this.captures});

  final String title;
  final List<Capture> captures;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x22000000)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 헤더(그라데이션 띠 + 제목).
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: AppTheme.brandGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                Text('${captures.length}컷의 기록',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: captures.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.78,
            ),
            itemBuilder: (context, i) => _PosterCell(capture: captures[i]),
          ),
          const SizedBox(height: 14),
          // 워터마크.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_outlined,
                  size: 14, color: Color(0xFFD25E49)),
              const SizedBox(width: 4),
              Text('그날 우리 · 매달 한 컷',
                  style: TextStyle(
                      color: const Color(0xFFD25E49).withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PosterCell extends StatelessWidget {
  const _PosterCell({required this.capture});
  final Capture capture;

  @override
  Widget build(BuildContext context) {
    final thumb = File(capture.thumbPath);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: thumb.existsSync()
                ? Image.file(thumb, fit: BoxFit.cover)
                : Container(color: const Color(0xFFE8DCD4)),
          ),
        ),
        const SizedBox(height: 3),
        Text(capture.periodLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: Color(0xFF6B5A52))),
      ],
    );
  }
}

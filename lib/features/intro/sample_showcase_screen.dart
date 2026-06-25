import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../services/providers.dart';
import '../../services/sample/sample_seeder.dart';
import '../home/home_providers.dart';

/// 첫 실행 쇼케이스 — 샘플 5컷이 **폴라로이드 타임랩스**로 도는 화면.
///
/// "같은 포즈로 한 컷씩 쌓으면 이렇게 된다"를 글 대신 움직임으로 보여준다.
/// 각 폴라로이드 하단에 손글씨 캡션(나이·장소 ♥)과 날짜(YYYY년 M월)를 얹어 감성을 더한다.
class SampleShowcaseScreen extends ConsumerWidget {
  const SampleShowcaseScreen({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref.watch(capturesProvider(project.id)).value ?? const [];
    final asc = [...caps]
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Column(
            children: [
              Text('이렇게 쌓여요',
                  style:
                      text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                '같은 포즈로 한 컷씩.\n시간이 지나면 이렇게 타임랩스가 됩니다.',
                textAlign: TextAlign.center,
                style:
                    text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: asc.isEmpty
                      ? const CircularProgressIndicator()
                      : FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: 300,
                            child: _PolaroidSlideshow(frames: asc),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
                onPressed: () async {
                  // 예시 사진은 내 데이터가 아니므로, 시작과 함께 깨끗이 제거.
                  await ref
                      .read(sampleSeederProvider)
                      .removeSample(project.id);
                  await ref.read(appSettingsProvider.notifier).markShowcaseSeen();
                },
                child: const Text('내 기록 시작하기'),
              ),
              const SizedBox(height: 10),
              Text(
                '위 사진은 예시예요. 시작하면 빈 앨범에서 우리만의 기록을 채워가요.',
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 폴라로이드 카드들을 시간순으로 부드럽게 크로스페이드(타임랩스).
class _PolaroidSlideshow extends StatefulWidget {
  const _PolaroidSlideshow({required this.frames});

  final List<Capture> frames; // 오래된→최근

  @override
  State<_PolaroidSlideshow> createState() => _PolaroidSlideshowState();
}

class _PolaroidSlideshowState extends State<_PolaroidSlideshow> {
  Timer? _timer;
  int _index = 0;
  bool _precached = false;

  // 디코드/래스터 비용을 줄이려 표시 크기에 맞춰 다운샘플(전환 끊김 방지).
  static const _decodeWidth = 720;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1300), (_) {
      if (!mounted || widget.frames.isEmpty) return;
      setState(() => _index = (_index + 1) % widget.frames.length);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 모든 프레임을 미리 디코딩해 둠 → 전환 순간 디코딩 jank 제거.
    if (_precached) return;
    _precached = true;
    for (final f in widget.frames) {
      final file = File(f.filePath);
      if (file.existsSync()) {
        precacheImage(
            ResizeImage(FileImage(file), width: _decodeWidth), context);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frames = widget.frames;
    if (frames.isEmpty) return const SizedBox.shrink();
    final i = _index.clamp(0, frames.length - 1);
    final cap = frames[i];
    final d = cap.capturedAt;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeOut,
      // 순수 페이드(스케일 제거 → 매 프레임 재래스터 비용 없앰).
      child: _PolaroidCard(
        key: ValueKey(i),
        imagePath: cap.filePath,
        caption: (cap.note != null && cap.note!.isNotEmpty)
            ? cap.note!
            : cap.periodLabel,
        dateLabel: '${d.year}년 ${d.month}월',
        angle: i.isEven ? -0.022 : 0.022,
      ),
    );
  }
}

/// 흰 프레임 + 하단 손글씨 캡션·날짜·하트의 폴라로이드 한 장.
class _PolaroidCard extends StatelessWidget {
  const _PolaroidCard({
    super.key,
    required this.imagePath,
    required this.caption,
    required this.dateLabel,
    required this.angle,
  });

  final String imagePath;
  final String caption;
  final String dateLabel;
  final double angle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final file = File(imagePath);

    return Transform.rotate(
      angle: angle,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 사진(폴라로이드 인화면).
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: file.existsSync()
                    ? Image.file(file,
                        fit: BoxFit.cover,
                        cacheWidth: 720,
                        gaplessPlayback: true)
                    : const ColoredBox(color: Colors.black12),
              ),
            ),
            const SizedBox(height: 12),
            // 손글씨 캡션(나이·장소 + 상황 이모지). 이모지는 시스템 폰트로 폴백 렌더.
            Text(
              caption,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'NanumPen',
                fontSize: 26,
                height: 1.0,
                color: Color(0xFF4A3A44),
              ),
            ),
            const SizedBox(height: 2),
            // 날짜(YYYY년 M월).
            Text(
              dateLabel,
              style: TextStyle(
                fontFamily: 'NanumPen',
                fontSize: 18,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

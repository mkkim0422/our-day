import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../data/db/app_database.dart';
import '../../capture/alignment_meta.dart';

/// 타임랩스 프레임 전환 방식.
enum PlaybackTransition {
  /// 은은하게 — 프레임이 서로 겹치며 페이드(깜박임 없음). 기본값.
  gentle,

  /// 바로 — 즉시 전환(컷).
  instant,
}

/// 인앱 타임랩스 재생 위젯 (⑤ — "타임랩스 재생").
///
/// 시간순 프레임을 타이머로 넘기며 보여준다. 각 프레임에 [AlignmentMeta]를
/// Transform으로 적용해 흔들림을 줄이고, 전환은 **크로스페이드(은은하게)** 가 기본이라
/// 컷 전환 특유의 깜박임이 없다. 우상단 토글로 "바로/은은하게"를 바꿀 수 있다.
class TimelapsePlayer extends StatefulWidget {
  const TimelapsePlayer({
    super.key,
    required this.framesAsc,
    this.frameDuration = const Duration(milliseconds: 1250),
  });

  /// 시간순(오래된→최근) 정렬된 촬영들.
  final List<Capture> framesAsc;
  final Duration frameDuration;

  @override
  State<TimelapsePlayer> createState() => _TimelapsePlayerState();
}

class _TimelapsePlayerState extends State<TimelapsePlayer> {
  Timer? _timer;
  int _index = 0;
  bool _playing = true;
  PlaybackTransition _transition = PlaybackTransition.gentle;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(TimelapsePlayer old) {
    super.didUpdateWidget(old);
    if (old.framesAsc.length != widget.framesAsc.length) {
      // 빈 리스트면 clamp(0, -1)이 ArgumentError를 던지므로 분기.
      _index = widget.framesAsc.isEmpty
          ? 0
          : _index.clamp(0, widget.framesAsc.length - 1);
    }
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.frameDuration, (_) {
      if (!mounted || widget.framesAsc.isEmpty) return;
      setState(() => _index = (_index + 1) % widget.framesAsc.length);
    });
  }

  void _togglePlay() {
    setState(() => _playing = !_playing);
    if (_playing) {
      _start();
    } else {
      _timer?.cancel();
    }
  }

  void _toggleTransition() {
    setState(() {
      _transition = _transition == PlaybackTransition.gentle
          ? PlaybackTransition.instant
          : PlaybackTransition.gentle;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frames = widget.framesAsc;
    if (frames.isEmpty) return const SizedBox.shrink();
    final current = frames[_index.clamp(0, frames.length - 1)];
    final gentle = _transition == PlaybackTransition.gentle;

    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Colors.black),
            // 크로스페이드(은은) 또는 즉시 전환(바로).
            AnimatedSwitcher(
              duration:
                  gentle ? const Duration(milliseconds: 600) : Duration.zero,
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              // 이전 프레임 위에 새 프레임이 겹쳐 페이드(전체화면 정렬).
              layoutBuilder: (currentChild, previousChildren) => Stack(
                fit: StackFit.expand,
                children: [
                  ...previousChildren,
                  ?currentChild,
                ],
              ),
              child: LayoutBuilder(
                key: ValueKey(_index),
                builder: (context, c) => _AlignedPhoto(
                  capture: current,
                  viewSize: Size(c.maxWidth, c.maxHeight),
                ),
              ),
            ),
            // 컨트롤 + 현재 기간 라벨.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _togglePlay,
                      icon: Icon(
                        _playing
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    Text(
                      current.periodLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_index + 1}/${frames.length}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    // 전환 방식 토글(은은하게/바로).
                    TextButton.icon(
                      onPressed: _toggleTransition,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      icon: Icon(gentle ? Icons.blur_on : Icons.bolt, size: 18),
                      label: Text(gentle ? '은은하게' : '바로'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 한 장의 사진을 [AlignmentMeta] 변환을 적용해 cover-fit으로 그린다.
class _AlignedPhoto extends StatelessWidget {
  const _AlignedPhoto({required this.capture, required this.viewSize});

  final Capture capture;
  final Size viewSize;

  @override
  Widget build(BuildContext context) {
    final file = File(capture.filePath);
    final align = capture.alignmentMeta != null
        ? AlignmentMeta.fromMap(capture.alignmentMeta!)
        : AlignmentMeta.identity;

    final image = file.existsSync()
        ? Image.file(file, fit: BoxFit.cover, gaplessPlayback: true)
        : const ColoredBox(color: Colors.black12);

    if (align.isIdentity) return image;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..translateByDouble(
            align.dx * viewSize.width, align.dy * viewSize.height, 0, 1)
        ..rotateZ(align.rotation)
        ..scaleByDouble(align.scale, align.scale, 1, 1),
      child: image,
    );
  }
}

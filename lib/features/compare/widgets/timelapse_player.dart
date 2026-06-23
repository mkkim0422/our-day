import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../data/db/app_database.dart';
import '../../capture/alignment_meta.dart';

/// 인앱 타임랩스 재생 위젯 (⑤ — "타임랩스 재생").
///
/// 시간순 프레임을 타이머로 넘기며 보여준다. 각 프레임에 [AlignmentMeta]를
/// Transform으로 적용해 흔들림을 줄인다(서버 합성 GIF와 동일한 정렬 기준).
/// 영상 인코딩 없이 화면에서 바로 재생하므로 4장 미만이어도 미리보기가 된다.
class TimelapsePlayer extends StatefulWidget {
  const TimelapsePlayer({
    super.key,
    required this.framesAsc,
    this.frameDuration = const Duration(milliseconds: 600),
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

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(TimelapsePlayer old) {
    super.didUpdateWidget(old);
    if (old.framesAsc.length != widget.framesAsc.length) {
      _index = _index.clamp(0, widget.framesAsc.length - 1);
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: Colors.black),
                LayoutBuilder(
                  builder: (context, c) => _AlignedPhoto(
                    capture: current,
                    viewSize: Size(c.maxWidth, c.maxHeight),
                  ),
                ),
                // 재생 컨트롤 + 현재 기간 라벨.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.55),
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
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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

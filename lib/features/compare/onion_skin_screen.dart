import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../capture/alignment_meta.dart';
import '../home/home_providers.dart';

/// 아이디어9 — 온스킨(잔상) 다중 오버레이.
///
/// 최근 여러 컷을 반투명으로 겹쳐, 같은 구도 위에 시간의 변화가 "잔상"처럼 쌓이는
/// 모습을 한 화면에서 보여준다. 슬라이더로 겹칠 컷 수를 조절.
class OnionSkinScreen extends ConsumerStatefulWidget {
  const OnionSkinScreen({super.key, required this.project});

  final Project project;

  @override
  ConsumerState<OnionSkinScreen> createState() => _OnionSkinScreenState();
}

class _OnionSkinScreenState extends ConsumerState<OnionSkinScreen> {
  int? _layers;

  @override
  Widget build(BuildContext context) {
    final capturesAsync = ref.watch(capturesProvider(widget.project.id));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('변화의 잔상'),
      ),
      body: capturesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('불러오기 오류: $e',
                style: const TextStyle(color: Colors.white))),
        data: (captures) {
          if (captures.length < 2) {
            return const Center(
              child: Text('사진이 2컷 이상이면 잔상을 볼 수 있어요.',
                  style: TextStyle(color: Colors.white54)),
            );
          }
          final asc = captures.reversed.toList(growable: false);
          final maxLayers = asc.length;
          final layers = (_layers ?? maxLayers).clamp(2, maxLayers);
          // 최근 layers개(window): 오래된 것일수록 옅게, 최신은 또렷하게.
          final window = asc.sublist(asc.length - layers);

          return Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final size = Size(c.maxWidth, c.maxHeight);
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            const ColoredBox(color: Colors.black),
                            for (var i = 0; i < window.length; i++)
                              Opacity(
                                // 맨 아래(가장 오래된)는 옅게, 맨 위(최신)는 1.0.
                                opacity: ((i + 1) / window.length)
                                    .clamp(0.18, 1.0),
                                child: _Layer(
                                    capture: window[i], viewSize: size),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.layers, color: Colors.white54, size: 20),
                    Expanded(
                      child: Slider(
                        value: layers.toDouble(),
                        min: 2,
                        max: maxLayers.toDouble(),
                        divisions: maxLayers - 2 == 0 ? null : maxLayers - 2,
                        label: '$layers컷',
                        onChanged: (v) => setState(() => _layers = v.round()),
                      ),
                    ),
                    Text('$layers컷',
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }
}

class _Layer extends StatelessWidget {
  const _Layer({required this.capture, required this.viewSize});
  final Capture capture;
  final Size viewSize;

  @override
  Widget build(BuildContext context) {
    final file = File(capture.filePath);
    if (!file.existsSync()) return const SizedBox.shrink();
    final align = capture.alignmentMeta != null
        ? AlignmentMeta.fromMap(capture.alignmentMeta!)
        : AlignmentMeta.identity;
    final image = Image.file(file, fit: BoxFit.cover, gaplessPlayback: true);
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

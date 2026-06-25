import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../services/providers.dart';
import 'decoration_themes.dart';

/// 사진 꾸미기 — 폴라로이드풍 프레임 10종 + 문구를 입혀 이미지로 공유/저장.
class DecorateScreen extends ConsumerStatefulWidget {
  const DecorateScreen({super.key, required this.project, required this.capture});

  final Project project;
  final Capture capture;

  @override
  ConsumerState<DecorateScreen> createState() => _DecorateScreenState();
}

class _DecorateScreenState extends ConsumerState<DecorateScreen> {
  final _boundaryKey = GlobalKey();
  late final TextEditingController _caption =
      TextEditingController(text: _defaultCaption());
  int _themeIndex = 0;
  bool _showDate = true;
  bool _busy = false;

  String _fmtDate() {
    final d = widget.capture.capturedAt;
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }

  String _defaultCaption() {
    final note = widget.capture.note;
    if (note != null && note.trim().isNotEmpty) return note.trim();
    final d = widget.capture.capturedAt;
    return '우리, ${d.year}.${d.month}.${d.day}';
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final share = ref.read(shareServiceProvider);
      final path =
          await share.captureBoundaryToPng(_boundaryKey, pixelRatio: 3);
      await share.shareFiles([path], text: '그날 우리 · 우리만의 한 컷');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('내보내기 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = kDecorThemes[_themeIndex];
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('꾸미기'),
        actions: [
          IconButton(
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.ios_share),
            tooltip: '공유 · 저장',
            onPressed: _busy ? null : _share,
          ),
        ],
      ),
      body: Column(
        children: [
          // 미리보기(이 영역 그대로 PNG로 캡처).
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: RepaintBoundary(
                    key: _boundaryKey,
                    child: SizedBox(
                      width: 300,
                      child: DecoratedCard(
                        capture: widget.capture,
                        caption: _caption.text,
                        theme: theme,
                        dateText: _showDate ? _fmtDate() : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 문구 입력 + 날짜 표시 토글.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _caption,
                    textAlign: TextAlign.center,
                    maxLength: 30,
                    decoration: const InputDecoration(
                      hintText: '문구를 입력하세요',
                      counterText: '',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: Icon(Icons.event,
                      size: 18,
                      color: _showDate ? scheme.primary : scheme.onSurfaceVariant),
                  label: const Text('날짜'),
                  selected: _showDate,
                  onSelected: (v) => setState(() => _showDate = v),
                ),
              ],
            ),
          ),
          // 테마 선택.
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: kDecorThemes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final t = kDecorThemes[i];
                final selected = i == _themeIndex;
                return GestureDetector(
                  onTap: () => setState(() => _themeIndex = i),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: t.frame.length == 1 ? t.frame.first : null,
                          gradient: t.frame.length > 1
                              ? LinearGradient(colors: t.frame)
                              : null,
                          border: Border.all(
                            color: selected
                                ? scheme.primary
                                : scheme.outlineVariant,
                            width: selected ? 2.5 : 1,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: t.accent.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(t.name,
                          style: TextStyle(
                            fontSize: 11,
                            color: selected
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                          )),
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton.icon(
                onPressed: _busy ? null : _share,
                icon: const Icon(Icons.ios_share),
                label: const Text('공유 · 저장'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

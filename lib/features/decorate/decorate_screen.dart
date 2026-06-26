import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/utils/age_label.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/providers.dart';
import '../../services/providers.dart';
import 'decor_models.dart';
import 'skin.dart';
import 'skin_card.dart';

/// 캔버스에 올린 스티커 1개(이모지). 위치는 카드 대비 정규화(0~1).
class _Sticker {
  _Sticker(this.emoji);
  final String emoji;
  double dx = 0.5, dy = 0.42, scale = 1, rotation = 0;
}

/// 사진 꾸미기 — **프리미엄 스킨**(카테고리별 큐레이션 템플릿)을 골라 문구·성장데이터와
/// 함께 입혀 이미지로 공유/저장. 딥리서치 기반 다축 재설계.
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

  /// 마지막으로 쓴 스킨 id(세션 동안 기억 — 다시 열 때 그 스킨으로 시작).
  static String? _lastSkinId;

  late Skin _skin = kSkins.firstWhere((s) => s.id == _lastSkinId,
      orElse: () => kSkins.first);
  late SkinCategory _category = _skin.category;
  bool _showDate = true;
  bool _showAge = true;
  bool _showHeight = true;
  double _filterStrength = 1.0; // 필터 세기
  double _captionScale = 1.0; // 글자 크기(0.8/1.0/1.25)
  bool _busy = false;

  // 스티커 레이어.
  final List<_Sticker> _stickers = [];
  int? _selectedSticker;
  double _cardW = 300;
  bool _showStickerPalette = false;
  double _baseScale = 1, _baseRot = 0;

  void _addSticker(String emoji) {
    setState(() {
      _stickers.add(_Sticker(emoji));
      _selectedSticker = _stickers.length - 1;
    });
  }

  void _removeSticker(int i) {
    setState(() {
      _stickers.removeAt(i);
      _selectedSticker = null;
    });
  }

  Widget _buildSticker(int i, _Sticker s) {
    final selected = _selectedSticker == i;
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment(s.dx * 2 - 1, s.dy * 2 - 1),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _selectedSticker = i),
        onScaleStart: (_) {
          setState(() => _selectedSticker = i);
          _baseScale = s.scale;
          _baseRot = s.rotation;
        },
        onScaleUpdate: (d) {
          final h = _boundaryKey.currentContext?.size?.height ?? _cardW * 1.5;
          setState(() {
            s.dx = (s.dx + d.focalPointDelta.dx / _cardW).clamp(0.02, 0.98);
            s.dy = (s.dy + d.focalPointDelta.dy / h).clamp(0.02, 0.98);
            s.scale = (_baseScale * d.scale).clamp(0.4, 4.0);
            s.rotation = _baseRot + d.rotation;
          });
        },
        child: Transform.rotate(
          angle: s.rotation,
          child: Transform.scale(
            scale: s.scale,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: selected
                  ? BoxDecoration(
                      border: Border.all(color: scheme.primary, width: 1),
                      borderRadius: BorderRadius.circular(6),
                    )
                  : null,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Text(s.emoji, style: TextStyle(fontSize: _cardW * 0.13)),
                  if (selected)
                    Positioned(
                      right: -12,
                      top: -12,
                      child: GestureDetector(
                        onTap: () => _removeSticker(i),
                        child: CircleAvatar(
                          radius: 11,
                          backgroundColor: scheme.error,
                          child: const Icon(Icons.close,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _defaultCaption() {
    final note = widget.capture.note;
    if (note != null && note.trim().isNotEmpty) return note.trim();
    return '우리, 그날';
  }

  String _fmtDate() {
    final d = widget.capture.capturedAt;
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  /// 폰트 로드 후 꾸민 카드를 PNG로 캡처(원본 사진은 건드리지 않음).
  Future<String> _capture() async {
    // 선택 테두리·삭제 버튼이 이미지에 찍히지 않게 해제 후 캡처.
    if (_selectedSticker != null) setState(() => _selectedSticker = null);
    await GoogleFonts.pendingFonts([GoogleFonts.getFont(_skin.font)]);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return ref.read(shareServiceProvider).captureBoundaryToPng(_boundaryKey,
        pixelRatio: 3);
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final path = await _capture();
      await ref.read(shareServiceProvider).shareFiles([path],
          text: '그날 우리 · 우리만의 한 컷');
    } catch (e) {
      _snack('내보내기 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 저장 — 꾸민 사진을 **앱 기록(타임라인)에 붙여** 보이게 한다.
  /// 원본 사진(filePath)은 타임랩스·오버레이용으로 그대로 보존. 갤러리에도 함께 담음.
  Future<void> _saveToRecords() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final path = await _capture(); // documents/exports (영구 보관)
      await ref
          .read(captureRepositoryProvider)
          .setDecoratedPath(widget.capture.id, path);
      // 갤러리에도 담기(권한/실패는 무시 — 기록 저장이 본질).
      try {
        if (!await Gal.hasAccess()) await Gal.requestAccess();
        await Gal.putImage(path, album: '그날 우리');
      } catch (_) {}
      if (mounted) {
        _snack('기록에 저장했어요. 원본은 그대로 보존돼요.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      _snack('저장 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider).value;
    final birthday = settings?.projectBirthdays[widget.project.id];
    final ageText = birthday != null
        ? AgeLabel.format(birthday, widget.capture.capturedAt)
        : null;
    final heightCm = settings?.captureHeights[widget.capture.id];
    final heightText = heightCm != null ? '${heightCm.toStringAsFixed(1)}cm' : null;

    final scheme = Theme.of(context).colorScheme;
    final skins = skinsForCategory(_category);

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
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                // 고정폭 캔버스(FittedBox 스케일 없이 1:1 → 스티커 드래그 정확).
                final w = math.min(c.maxWidth - 24, (c.maxHeight - 24) / 1.62);
                _cardW = w;
                return Center(
                  // 빈 곳 탭 → 스티커 선택 해제.
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedSticker = null),
                    child: RepaintBoundary(
                      key: _boundaryKey,
                      child: SizedBox(
                        width: w,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            SkinCard(
                              skin: _skin,
                              capture: widget.capture,
                              caption: _caption.text,
                              dateText: _showDate ? _fmtDate() : null,
                              ageText: (_showAge ? ageText : null),
                              heightText: (_showHeight ? heightText : null),
                              filterStrength: _filterStrength,
                              captionScale: _captionScale,
                              width: w,
                            ),
                            for (var i = 0; i < _stickers.length; i++)
                              _buildSticker(i, _stickers[i]),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          _controls(context, scheme, ageText, heightText, skins),
        ],
      ),
    );
  }

  Widget _controls(BuildContext context, ColorScheme scheme, String? ageText,
      String? heightText, List<Skin> skins) {
    return Material(
      color: scheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 문구 + 표시 토글.
              Row(
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
                ],
              ),
              const SizedBox(height: 8),
              // 스티커 추가 토글 + 팔레트.
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(
                      () => _showStickerPalette = !_showStickerPalette),
                  icon: Icon(_showStickerPalette
                      ? Icons.expand_less
                      : Icons.emoji_emotions_outlined),
                  label: const Text('스티커'),
                ),
              ),
              if (_showStickerPalette)
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final e in kStickerPalette)
                        GestureDetector(
                          onTap: () => _addSticker(e),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Center(
                                child: Text(e,
                                    style: const TextStyle(fontSize: 26))),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _toggle('날짜', _showDate, (v) => setState(() => _showDate = v)),
                  if (ageText != null)
                    _toggle('나이', _showAge, (v) => setState(() => _showAge = v)),
                  if (heightText != null)
                    _toggle('키', _showHeight,
                        (v) => setState(() => _showHeight = v)),
                  // 글자 크기.
                  _toggle('글자 작게', _captionScale == 0.8,
                      (_) => setState(() => _captionScale = 0.8)),
                  _toggle('보통', _captionScale == 1.0,
                      (_) => setState(() => _captionScale = 1.0)),
                  _toggle('크게', _captionScale == 1.25,
                      (_) => setState(() => _captionScale = 1.25)),
                ],
              ),
              const SizedBox(height: 6),
              // 필터 세기.
              Row(
                children: [
                  const Icon(Icons.tune, size: 18),
                  const SizedBox(width: 4),
                  const Text('필터', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: _filterStrength,
                      onChanged: (v) => setState(() => _filterStrength = v),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text('${(_filterStrength * 100).round()}%',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // 카테고리 탭.
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final c in SkinCategory.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(kCategoryNames[c]!),
                          selected: _category == c,
                          onSelected: (_) => setState(() {
                            _category = c;
                            _skin = skinsForCategory(c).first;
                          }),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // 스킨 썸네일.
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: skins.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => _skinThumb(skins[i], scheme),
                ),
              ),
              const SizedBox(height: 12),
              // 저장(갤러리) + 공유. 원본은 타임라인에 그대로 보존.
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _saveToRecords,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('저장'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _share,
                      icon: const Icon(Icons.ios_share),
                      label: const Text('공유'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: onChanged,
    );
  }

  Widget _skinThumb(Skin skin, ColorScheme scheme) {
    final selected = skin.id == _skin.id;
    return GestureDetector(
      onTap: () {
        setState(() => _skin = skin);
        _lastSkinId = skin.id; // 다음에 열 때 기억.
      },
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Container(
              width: 64,
              height: 78,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: selected ? scheme.primary : scheme.outlineVariant,
                  width: selected ? 2.5 : 1,
                ),
              ),
              // 실제 내 사진 + 스킨 룩(필터·배경·모티프) 미니 미리보기.
              child: SkinThumb(skin: skin, capture: widget.capture),
            ),
            const SizedBox(height: 4),
            Text(skin.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                )),
          ],
        ),
      ),
    );
  }
}

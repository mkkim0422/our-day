import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/utils/age_label.dart';
import '../../data/db/app_database.dart';
import '../../services/providers.dart';
import 'skin.dart';
import 'skin_card.dart';

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

  SkinCategory _category = SkinCategory.minimal;
  late Skin _skin = skinsForCategory(_category).first;
  bool _showDate = true;
  bool _showAge = true;
  bool _showHeight = true;
  bool _busy = false;

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
    await GoogleFonts.pendingFonts([GoogleFonts.getFont(_skin.font)]);
    await Future<void>.delayed(const Duration(milliseconds: 60));
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

  /// 갤러리에 저장 — **원본은 타임라인에 그대로 보존**, 꾸민 사진만 사진앱에 추가.
  Future<void> _saveToGallery() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final path = await _capture();
      if (!await Gal.hasAccess()) await Gal.requestAccess();
      await Gal.putImage(path, album: '그날 우리');
      _snack('갤러리에 저장했어요. 원본은 타임라인에 그대로 있어요.');
    } on GalException catch (e) {
      _snack('저장 실패: ${e.type.message}');
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
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: RepaintBoundary(
                    key: _boundaryKey,
                    child: SkinCard(
                      skin: _skin,
                      capture: widget.capture,
                      caption: _caption.text,
                      dateText: _showDate ? _fmtDate() : null,
                      ageText: (_showAge ? ageText : null),
                      heightText: (_showHeight ? heightText : null),
                    ),
                  ),
                ),
              ),
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
              Wrap(
                spacing: 8,
                children: [
                  _toggle('날짜', _showDate, (v) => setState(() => _showDate = v)),
                  if (ageText != null)
                    _toggle('나이', _showAge, (v) => setState(() => _showAge = v)),
                  if (heightText != null)
                    _toggle('키', _showHeight,
                        (v) => setState(() => _showHeight = v)),
                ],
              ),
              const SizedBox(height: 10),
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
                      onPressed: _busy ? null : _saveToGallery,
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
    final isDark = skin.bg.first.computeLuminance() < 0.35;
    return GestureDetector(
      onTap: () => setState(() => _skin = skin),
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: skin.bg.length == 1 ? skin.bg.first : null,
                gradient: skin.bg.length > 1
                    ? LinearGradient(colors: skin.bg)
                    : null,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? scheme.primary : scheme.outlineVariant,
                  width: selected ? 2.5 : 1,
                ),
              ),
              child: Center(
                child: Container(
                  width: 34,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: skin.accent.withValues(alpha: 0.6)),
                  ),
                  child: Center(
                    child: Icon(Icons.favorite,
                        size: 14, color: skin.accent),
                  ),
                ),
              ),
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

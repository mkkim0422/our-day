import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/providers.dart';

/// PIN 해시(평문 저장 안 함). 짧은 PIN이라 강력 보안은 아니지만 앨범 가림용으로 충분.
String hashPin(String pin) =>
    sha256.convert(utf8.encode('ourday-lock:$pin')).toString();

/// 이번 실행에서 잠금을 해제했는지(세션). 콜드스타트마다 다시 잠긴다.
class AppUnlocked extends Notifier<bool> {
  @override
  bool build() => false;
  void unlock() => state = true;
}

final appUnlockedProvider =
    NotifierProvider<AppUnlocked, bool>(AppUnlocked.new);

/// 앱 잠금 게이트 — 잠금이 켜져 있고 아직 해제 안 했으면 [LockScreen]을, 아니면 [child].
class LockGate extends ConsumerWidget {
  const LockGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider).value;
    final unlocked = ref.watch(appUnlockedProvider);
    if (settings == null) {
      // 설정 로딩 중엔 내용 노출 방지(짧음).
      return const ColoredBox(color: Color(0xFFF8F2F7));
    }
    if (settings.lockPinHash != null && !unlocked) {
      return LockScreen(expectedHash: settings.lockPinHash!);
    }
    return child;
  }
}

/// 잠금 해제 화면 — 저장된 PIN과 일치하면 세션 해제.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key, required this.expectedHash});
  final String expectedHash;

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _pin = '';
  bool _error = false;

  void _onDigit(String d) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += d;
      _error = false;
    });
    if (_pin.length == 4) _verify();
  }

  void _onBack() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _verify() {
    if (hashPin(_pin) == widget.expectedHash) {
      ref.read(appUnlockedProvider.notifier).unlock();
    } else {
      setState(() {
        _error = true;
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Icon(Icons.lock_outline, size: 44, color: scheme.primary),
            const SizedBox(height: 16),
            Text('PIN을 입력하세요',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(_error ? 'PIN이 일치하지 않아요' : '앨범을 보호하고 있어요',
                style: TextStyle(
                    color: _error ? scheme.error : scheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            PinDots(length: _pin.length, error: _error),
            const Spacer(),
            PinPad(onDigit: _onDigit, onBack: _onBack),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}

/// PIN 4자리 입력 화면(설정·확인용). 입력 완료 시 4자리 문자열을 pop, 취소 시 null.
class PinPromptScreen extends StatefulWidget {
  const PinPromptScreen({super.key, required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  State<PinPromptScreen> createState() => _PinPromptScreenState();
}

class _PinPromptScreenState extends State<PinPromptScreen> {
  String _pin = '';

  void _onDigit(String d) {
    if (_pin.length >= 4) return;
    setState(() => _pin += d);
    if (_pin.length == 4) Navigator.of(context).pop(_pin);
  }

  void _onBack() {
    if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            if (widget.subtitle != null)
              Text(widget.subtitle!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            PinDots(length: _pin.length, error: false),
            const Spacer(),
            PinPad(onDigit: _onDigit, onBack: _onBack),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}

/// 4자리 PIN 점 표시.
class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.length, required this.error});
  final int length;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final filled = i < length;
        return Container(
          width: 16,
          height: 16,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled
                ? (error ? scheme.error : scheme.primary)
                : Colors.transparent,
            border: Border.all(
                color: error ? scheme.error : scheme.outlineVariant, width: 1.5),
          ),
        );
      }),
    );
  }
}

/// 숫자 패드(1~9, 0, 지우기).
class PinPad extends StatelessWidget {
  const PinPad({super.key, required this.onDigit, required this.onBack});
  final ValueChanged<String> onDigit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    Widget key(String label, {VoidCallback? onTap, Widget? child}) => SizedBox(
          width: 78,
          height: 78,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(40),
            child: Center(
              child: child ??
                  Text(label,
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w600)),
            ),
          ),
        );

    Widget row(List<Widget> cs) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: cs,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row([key('1', onTap: () => onDigit('1')), key('2', onTap: () => onDigit('2')), key('3', onTap: () => onDigit('3'))]),
        row([key('4', onTap: () => onDigit('4')), key('5', onTap: () => onDigit('5')), key('6', onTap: () => onDigit('6'))]),
        row([key('7', onTap: () => onDigit('7')), key('8', onTap: () => onDigit('8')), key('9', onTap: () => onDigit('9'))]),
        row([
          key(''),
          key('0', onTap: () => onDigit('0')),
          key('', onTap: onBack, child: const Icon(Icons.backspace_outlined)),
        ]),
      ],
    );
  }
}

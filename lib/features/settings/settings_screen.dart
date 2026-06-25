import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/location/location_service.dart';
import '../../services/providers.dart';
import 'app_lock.dart';
import 'privacy_policy_screen.dart';

/// 앱 전역 설정 — 위치 회상 · 앱 잠금 · 정보.
///
/// 앨범별 항목(주인공 생일·구성원)은 앨범 설정으로 분리. 데이터 안전(백업)은
/// 자체 서버 미보관 원칙(9장)에 따라 사용자 클라우드 자동 백업으로 추후 제공한다.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _appVersion = '1.0.0';

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider).value;
    final loading = ref.watch(appSettingsProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          _sectionTitle('알림'),
          SwitchListTile(
            secondary: const Icon(Icons.location_on_outlined),
            title: const Text('위치 기반 회상 알림'),
            subtitle:
                const Text('같은 장소에 다시 오면 그때 사진을 띄워드려요. 위치는 이 용도로만 쓰여요.'),
            value: settings?.locationRecallEnabled ?? false,
            onChanged: loading ? null : _toggleLocationRecall,
          ),
          const Divider(height: 32),
          _sectionTitle('보안'),
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline),
            title: const Text('앱 잠금'),
            subtitle: Text(settings?.appLockEnabled == true
                ? 'PIN을 입력해야 앨범을 볼 수 있어요'
                : '4자리 PIN으로 앨범을 보호해요'),
            value: settings?.appLockEnabled ?? false,
            onChanged: loading ? null : _toggleAppLock,
          ),
          if (settings?.appLockEnabled == true)
            ListTile(
              leading: const Icon(Icons.password),
              title: const Text('PIN 변경'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _changePin,
            ),
          const Divider(height: 32),
          _sectionTitle('정보'),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('개인정보 처리방침'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('오픈소스 라이선스'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: '그날 우리',
              applicationVersion: _appVersion,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('문의'),
            subtitle: const Text('help@sphinfo.co.kr'),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('버전'),
            trailing: Text(_appVersion,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
      );

  Future<void> _toggleLocationRecall(bool enabled) async {
    if (enabled) {
      final location = ref.read(locationServiceProvider);
      final auth = await location.requestPermission();
      if (auth != LocationAuth.granted) {
        if (!mounted) return;
        if (auth == LocationAuth.deniedForever) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('위치 권한이 꺼져 있어요. 설정에서 허용해 주세요.'),
              action: SnackBarAction(
                  label: '설정 열기', onPressed: location.openSettings),
            ),
          );
        } else if (auth == LocationAuth.serviceOff) {
          _snack('기기의 위치 서비스가 꺼져 있어요. 위치를 켜고 다시 시도해 주세요.');
        } else {
          _snack('위치 권한이 필요해요.');
        }
        return;
      }
    }
    await ref.read(appSettingsProvider.notifier).setLocationRecallEnabled(enabled);
    if (mounted) {
      _snack(enabled ? '위치 기반 회상 알림을 켰어요.' : '위치 기반 회상 알림을 껐어요.');
    }
  }

  Future<void> _toggleAppLock(bool enabled) async {
    if (enabled) {
      final pin = await _promptPin('PIN 설정', '4자리 숫자를 입력하세요');
      if (pin == null) return;
      if (!mounted) return;
      final confirm = await _promptPin('PIN 확인', '한 번 더 입력하세요');
      if (confirm == null) return;
      if (pin != confirm) {
        _snack('PIN이 일치하지 않아요. 다시 시도해 주세요.');
        return;
      }
      await ref.read(appSettingsProvider.notifier).setLockPin(hashPin(pin));
      _snack('앱 잠금을 켰어요.');
    } else {
      // 끌 때 현재 PIN 확인.
      final pin = await _promptPin('PIN 확인', '현재 PIN을 입력하세요');
      if (pin == null) return;
      final expected = ref.read(appSettingsProvider).value?.lockPinHash;
      if (hashPin(pin) != expected) {
        _snack('PIN이 일치하지 않아요.');
        return;
      }
      await ref.read(appSettingsProvider.notifier).setLockPin(null);
      _snack('앱 잠금을 껐어요.');
    }
  }

  Future<void> _changePin() async {
    final current = await _promptPin('현재 PIN', '현재 PIN을 입력하세요');
    if (current == null) return;
    final expected = ref.read(appSettingsProvider).value?.lockPinHash;
    if (hashPin(current) != expected) {
      _snack('현재 PIN이 일치하지 않아요.');
      return;
    }
    if (!mounted) return;
    final next = await _promptPin('새 PIN', '새 4자리 PIN을 입력하세요');
    if (next == null) return;
    await ref.read(appSettingsProvider.notifier).setLockPin(hashPin(next));
    _snack('PIN을 변경했어요.');
  }

  Future<String?> _promptPin(String title, String subtitle) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PinPromptScreen(title: title, subtitle: subtitle),
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}

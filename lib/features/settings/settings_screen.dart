import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/repositories/providers.dart';
import '../../services/backup/local_backup_service.dart';
import '../../services/location/location_service.dart';
import '../../services/providers.dart';
import 'app_lock.dart';
import 'privacy_policy_screen.dart';
import 'settings_providers.dart';

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
          _sectionTitle('데이터 백업'),
          const ListTile(
            leading: Icon(Icons.shield_outlined),
            title: Text('사진은 이 기기에 저장돼요'),
            subtitle: Text(
                '폰을 바꾸거나 앱을 지우면 사라질 수 있어요. 백업을 만들어 구글 드라이브·카톡 등에 보관해 두세요.'),
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('백업 만들기'),
            subtitle: const Text('사진·기록·꾸민 사진·설정까지 파일 하나로 묶어요'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _createBackup,
          ),
          ListTile(
            leading: const Icon(Icons.restore_outlined),
            title: const Text('백업에서 복원'),
            subtitle: const Text('다른 기기의 백업 파일(.zip)을 불러와 되살려요'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _restoreFromExternal,
          ),
          _backupsList(),
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
            subtitle: const Text('mkkim850422@gmail.com'),
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
      if (!mounted) return;
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
      if (!mounted) return;
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
    if (!mounted) return;
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

  // ── 백업/복원 ──

  /// 이 기기에 저장된 백업 목록.
  Widget _backupsList() {
    final backupsAsync = ref.watch(backupsProvider);
    return backupsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (backups) {
        if (backups.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('이 기기의 백업',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            for (final b in backups)
              ListTile(
                dense: true,
                leading: const Icon(Icons.folder_zip_outlined),
                title: Text(_fmtDate(b.modifiedAt)),
                subtitle: Text(_fmtSize(b.sizeBytes)),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'share') _shareBackup(b);
                    if (v == 'restore') _restoreFromPath(b.path);
                    if (v == 'delete') _deleteBackup(b);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'share', child: Text('내보내기 · 공유')),
                    PopupMenuItem(value: 'restore', child: Text('이 백업으로 복원')),
                    PopupMenuItem(value: 'delete', child: Text('삭제')),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _createBackup() async {
    final path = await _withProgress<String>(
      '백업을 만들고 있어요…',
      () => ref.read(localBackupServiceProvider).createBackup(),
    );
    if (path == null || !mounted) return;
    ref.invalidate(backupsProvider);
    final share = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('백업을 만들었어요'),
        content: const Text(
            '폰 교체·앱 삭제에 대비해 이 파일을 구글 드라이브나 카톡 등 안전한 곳에 내보내 보관하세요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('나중에')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('지금 내보내기')),
        ],
      ),
    );
    if (share == true) {
      await ref
          .read(shareServiceProvider)
          .shareFiles([path], text: '그날 우리 백업');
    }
  }

  /// 외부 .zip 선택 → 복원(새 기기 시나리오).
  Future<void> _restoreFromExternal() async {
    XFile? file;
    try {
      const typeGroup = XTypeGroup(label: '백업 파일', extensions: ['zip']);
      file = await openFile(acceptedTypeGroups: [typeGroup]);
    } catch (e) {
      _snack('파일 선택 실패: $e');
      return;
    }
    if (file == null) return;
    await _restoreFromPath(file.path);
  }

  Future<void> _restoreFromPath(String path) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('백업에서 복원할까요?'),
        content: const Text(
            '지금 이 기기의 사진·기록이 백업 내용으로 교체돼요. 되돌릴 수 없으니, 필요하면 먼저 현재 상태를 백업해 두세요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('복원')),
        ],
      ),
    );
    if (ok != true) return;

    final count = await _withProgress<int>(
      '복원하고 있어요…',
      () => ref.read(localBackupServiceProvider).restoreFromFile(path),
    );
    if (count == null || !mounted) return;

    // DB 밖 설정(생일·키·앱잠금) 재로딩 + 목록 갱신.
    ref.invalidate(appSettingsProvider);
    ref.invalidate(backupsProvider);

    // 복원된 프로젝트들의 알림을 다시 예약(복원 직후엔 예약이 비어 있으므로).
    await _rescheduleAllNotifications();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('복원 완료'),
        content: Text(
            '$count개의 기록을 되살렸어요.\n모든 화면에 완전히 반영되도록 앱을 종료했다가 다시 열어 주세요.'),
        actions: [
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('확인')),
        ],
      ),
    );
  }

  /// 복원 후 모든 프로젝트의 주기·회상·이벤트 알림을 다시 예약(best-effort).
  Future<void> _rescheduleAllNotifications() async {
    try {
      final projects =
          await ref.read(projectRepositoryProvider).watchAll().first;
      final settings = await ref.read(appSettingsProvider.future);
      final notif = ref.read(notificationServiceProvider);
      final capRepo = ref.read(captureRepositoryProvider);
      for (final pj in projects) {
        final caps = await capRepo.listByProject(pj.id);
        await notif.scheduleForProject(
          pj,
          caps,
          birthday: settings.projectBirthdays[pj.id],
        );
      }
    } catch (_) {
      // 알림 재예약은 best-effort — 실패해도 복원 자체는 성공.
    }
  }

  Future<void> _shareBackup(BackupFileInfo b) async {
    await ref
        .read(shareServiceProvider)
        .shareFiles([b.path], text: '그날 우리 백업');
  }

  Future<void> _deleteBackup(BackupFileInfo b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이 백업을 삭제할까요?'),
        content: const Text('이 기기에 저장된 백업 파일만 지워져요. 내보내 둔 파일은 그대로예요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(localBackupServiceProvider).deleteBackup(b.path);
    ref.invalidate(backupsProvider);
  }

  /// 모달 진행 표시와 함께 [task] 실행. 실패 시 스낵바, 결과는 성공 시에만 반환.
  Future<T?> _withProgress<T>(String message, Future<T> Function() task) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5)),
              const SizedBox(width: 18),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );
    try {
      final result = await task();
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      return result;
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _snack('오류가 났어요: $e');
      return null;
    }
  }

  String _fmtDate(DateTime d) =>
      DateFormat('yyyy.MM.dd HH:mm').format(d);

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

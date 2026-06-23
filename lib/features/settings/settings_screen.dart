import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/repositories/providers.dart';
import '../../services/backup/local_backup_service.dart';
import '../../services/location/location_service.dart';
import '../../services/providers.dart';
import '../../services/settings/app_settings.dart';
import '../members/members_screen.dart';
import 'settings_providers.dart';

/// ③ 설정 / 백업 — 데이터 안전(분실 대비)과 권한 관리.
///
/// MVP 백업은 **로컬 zip 파일**(manifest+사진)을 만들어 사용자가 본인 클라우드로
/// 직접 공유하거나 기기 변경 시 복원하는 방식(9장 local-first). 구글 드라이브/iCloud
/// 자동 백업과 소셜 로그인은 동일 구조 위에 올라갈 예정(작업 #future).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.project});

  /// 현재 프로젝트(있으면 "주인공 생일" 등 프로젝트별 설정 노출).
  final Project? project;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final accountAsync = ref.watch(currentAccountProvider);
    final backupsAsync = ref.watch(backupsProvider);
    final settingsAsync = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('설정 · 백업')),
      body: ListView(
        children: [
          if (widget.project != null) ...[
            _sectionTitle('프로젝트'),
            _birthdayTile(settingsAsync.value),
            ListTile(
              leading: const Icon(Icons.group_outlined),
              title: const Text('구성원'),
              subtitle: const Text('가족을 추가해 사진에 태그하고 필터링'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => MembersScreen(project: widget.project!)),
              ),
            ),
            const Divider(height: 32),
          ],
          _sectionTitle('계정'),
          accountAsync.when(
            loading: () => const ListTile(title: Text('확인 중…')),
            error: (e, _) => ListTile(title: Text('오류: $e')),
            data: (account) => _accountTile(account),
          ),
          const Divider(height: 32),
          _sectionTitle('백업'),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('백업 파일 만들기'),
            subtitle: const Text('사진+기록을 zip으로 묶어 내 클라우드/메일로 공유'),
            trailing: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _busy ? null : _createAndShareBackup,
          ),
          _sectionTitle('이 기기의 백업 파일'),
          backupsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => ListTile(title: Text('목록 오류: $e')),
            data: (backups) => backups.isEmpty
                ? const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text('아직 만든 백업이 없어요.'),
                  )
                : Column(
                    children: [
                      for (final b in backups) _backupTile(b),
                    ],
                  ),
          ),
          const Divider(height: 32),
          _sectionTitle('위치 기반 회상 알림'),
          SwitchListTile(
            secondary: const Icon(Icons.location_on_outlined),
            title: const Text('위치 기반 회상 알림'),
            subtitle: const Text('같은 장소에 다시 오면 그때 사진을 띄워드려요. 위치는 이 용도로만 쓰여요.'),
            value: settingsAsync.value?.locationRecallEnabled ?? false,
            onChanged:
                settingsAsync.isLoading ? null : _toggleLocationRecall,
          ),
          const Divider(height: 32),
          _sectionTitle('보안 (준비 중)'),
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('앱 잠금 (생체인증)'),
            subtitle: Text('앨범 보호 (작업 예정)'),
            enabled: false,
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

  Widget _accountTile(Account? account) {
    if (account == null) {
      return Column(
        children: [
          const ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('로그인 안 됨'),
            subtitle: Text('로그인하면 클라우드 자동 백업을 쓸 수 있어요'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _comingSoon('구글 로그인'),
                    icon: const Icon(Icons.account_circle_outlined),
                    label: const Text('Google'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _comingSoon('Apple 로그인'),
                    icon: const Icon(Icons.apple),
                    label: const Text('Apple'),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return ListTile(
      leading: const Icon(Icons.person),
      title: Text(account.displayName ?? account.provider.name),
      subtitle: Text('${account.provider.name} 로그인됨'),
      trailing: TextButton(
        onPressed: _logout,
        child: const Text('로그아웃'),
      ),
    );
  }

  Widget _backupTile(BackupFileInfo b) {
    return ListTile(
      leading: const Icon(Icons.folder_zip_outlined),
      title: Text(_formatDateTime(b.modifiedAt)),
      subtitle: Text(_formatSize(b.sizeBytes)),
      trailing: TextButton(
        onPressed: _busy ? null : () => _confirmRestore(b),
        child: const Text('복원'),
      ),
    );
  }

  Future<void> _createAndShareBackup() async {
    setState(() => _busy = true);
    try {
      final backup = ref.read(localBackupServiceProvider);
      final path = await backup.createBackup();

      // 로그인 상태면 마지막 백업 시각 기록.
      final account = ref.read(currentAccountProvider).value;
      if (account != null) {
        await ref
            .read(accountRepositoryProvider)
            .setLastBackupAt(account.id, DateTime.now());
      }

      ref.invalidate(backupsProvider);
      await ref.read(shareServiceProvider).shareFiles(
        [path],
        text: '그날 우리 백업',
      );
      _snack('백업 파일을 만들었어요.');
    } catch (e) {
      _snack('백업 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmRestore(BackupFileInfo b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이 백업으로 복원할까요?'),
        content: const Text('현재 기기의 사진·기록이 백업 내용으로 교체돼요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('복원'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      final count =
          await ref.read(localBackupServiceProvider).restoreFromFile(b.path);
      _snack('$count장의 사진을 복원했어요.');
    } catch (e) {
      _snack('복원 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _birthdayTile(AppSettingsData? settings) {
    final birthday = settings?.projectBirthdays[widget.project!.id];
    final label = birthday == null
        ? '설정 안 함'
        : '${birthday.year}.${birthday.month.toString().padLeft(2, '0')}.${birthday.day.toString().padLeft(2, '0')}';
    return ListTile(
      leading: const Icon(Icons.cake_outlined),
      title: const Text('주인공 생일'),
      subtitle: Text('$label · 사진에 나이가 표시돼요'),
      trailing: birthday != null
          ? IconButton(
              icon: const Icon(Icons.clear),
              tooltip: '생일 지우기',
              onPressed: () => ref
                  .read(appSettingsProvider.notifier)
                  .setProjectBirthday(widget.project!.id, null),
            )
          : null,
      onTap: _pickBirthday,
    );
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final current =
        ref.read(appSettingsProvider).value?.projectBirthdays[widget.project!.id];
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      helpText: '주인공 생일',
    );
    if (picked != null) {
      await ref
          .read(appSettingsProvider.notifier)
          .setProjectBirthday(widget.project!.id, picked);
    }
  }

  Future<void> _toggleLocationRecall(bool enabled) async {
    // 켤 때만 위치 권한을 요청(5장 — opt-in, 강요하지 않음).
    if (enabled) {
      final location = ref.read(locationServiceProvider);
      final auth = await location.requestPermission();
      if (auth != LocationAuth.granted) {
        if (!mounted) return;
        if (auth == LocationAuth.deniedForever) {
          // 영구 거부 — 앱 설정에서만 회복 가능. 바로 열어줄 수 있게 안내.
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

  Future<void> _logout() async {
    await ref.read(accountRepositoryProvider).clear();
    _snack('로그아웃했어요. (사진·기록은 기기에 그대로 있어요)');
  }

  void _comingSoon(String label) => _snack('$label은 곧 제공됩니다.');

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String _formatDateTime(DateTime d) =>
      '${d.year}.${_two(d.month)}.${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';

  String _two(int n) => n.toString().padLeft(2, '0');

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

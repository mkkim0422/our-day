import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../services/providers.dart';
import '../../services/settings/app_settings.dart';
import '../members/members_screen.dart';
import 'settings_screen.dart';

/// 앨범(프로젝트)별 설정 — 주인공 생일·구성원처럼 **이 앨범에만** 적용되는 항목.
/// 앱 전역 설정([SettingsScreen])과 분리(생일·구성원은 앨범마다 다르므로).
class AlbumSettingsScreen extends ConsumerStatefulWidget {
  const AlbumSettingsScreen({super.key, required this.project});
  final Project project;

  @override
  ConsumerState<AlbumSettingsScreen> createState() =>
      _AlbumSettingsScreenState();
}

class _AlbumSettingsScreenState extends ConsumerState<AlbumSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.project.title} 설정')),
      body: ListView(
        children: [
          _birthdayTile(settings),
          ListTile(
            leading: const Icon(Icons.group_outlined),
            title: const Text('구성원'),
            subtitle: const Text('가족을 추가해 사진에 태그하고, 비교에서 필터링'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => MembersScreen(project: widget.project)),
            ),
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('앱 설정'),
            subtitle: const Text('위치 회상·앱 잠금·정보 등 전체 설정'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _birthdayTile(AppSettingsData? settings) {
    final birthday = settings?.projectBirthdays[widget.project.id];
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
                  .setProjectBirthday(widget.project.id, null),
            )
          : null,
      onTap: _pickBirthday,
    );
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final current = ref
        .read(appSettingsProvider)
        .value
        ?.projectBirthdays[widget.project.id];
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
          .setProjectBirthday(widget.project.id, picked);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/repositories/providers.dart';

/// 구성원 관리 (아이디어7) — 프로젝트에 가족 구성원을 추가/삭제.
/// 추가한 구성원은 사진 상세에서 "함께한 사람"으로 태그할 수 있다.
class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(membersProvider(project.id));

    return Scaffold(
      appBar: AppBar(title: const Text('구성원')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addMember(context, ref),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('구성원 추가'),
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오기 오류: $e')),
        data: (members) {
          if (members.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.group_outlined,
                        size: 56,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text('아직 구성원이 없어요',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text('가족을 추가하면 사진마다 누가 있었는지 태그하고,\n특정 구성원만 타임랩스로 볼 수 있어요.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            );
          }
          return ListView(
            children: [
              for (final m in members)
                ListTile(
                  leading: CircleAvatar(
                    child: Text(m.name.isNotEmpty ? m.name.characters.first : '?'),
                  ),
                  title: Text(m.name),
                  subtitle: m.role != null ? Text(m.role!) : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: '삭제',
                    onPressed: () => _confirmDelete(context, ref, m),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addMember(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final roleController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('구성원 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: '이름'),
            ),
            TextField(
              controller: roleController,
              decoration: const InputDecoration(labelText: '관계 (선택, 예: 엄마/첫째)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('추가')),
        ],
      ),
    );
    if (ok != true) return;
    final name = nameController.text.trim();
    if (name.isEmpty) return;
    await ref.read(memberRepositoryProvider).create(
          projectId: project.id,
          name: name,
          role: roleController.text.trim().isEmpty
              ? null
              : roleController.text.trim(),
        );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Member member) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${member.name} 삭제'),
        content: const Text('이 구성원과 사진 태그가 모두 제거돼요. (사진 자체는 유지)'),
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
    if (ok == true) {
      await ref.read(memberRepositoryProvider).delete(member.id);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/providers.dart';
import '../../services/providers.dart';

/// ① 첫 프로젝트 생성 화면.
///
/// 진입 장벽 최소화(3장): 프로젝트명 + 촬영 주기 + 이벤트 페그(선택)만 받는다.
/// 소셜 로그인·클라우드 백업 연결은 작업 #7에서 이 흐름 앞단에 붙인다(현재는 로컬-퍼스트).
class NewProjectScreen extends ConsumerStatefulWidget {
  const NewProjectScreen({super.key});

  @override
  ConsumerState<NewProjectScreen> createState() => _NewProjectScreenState();
}

class _NewProjectScreenState extends ConsumerState<NewProjectScreen> {
  final _titleController = TextEditingController();
  ScheduleType _scheduleType = ScheduleType.monthly;
  EventPeg _eventPeg = EventPeg.none;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  bool get _canSubmit => _titleController.text.trim().isNotEmpty && !_saving;

  Future<void> _create() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);
    try {
      final project = await ref.read(projectRepositoryProvider).create(
            title: title,
            scheduleType: _scheduleType,
            scheduleConfig: _defaultConfig(_scheduleType),
            eventPeg: _eventPeg,
          );

      // 알림 권한은 실제 필요한 시점(첫 프로젝트 생성)에 단계적으로 요청(3·9장).
      // manual 주기는 예약할 게 없으므로 권한도 강요하지 않는다.
      final notifications = ref.read(notificationServiceProvider);
      if (_scheduleType != ScheduleType.manual) {
        await notifications.requestPermission();
      }
      await notifications.scheduleForProject(project, const []);

      if (mounted) Navigator.of(context).pop<Project>(project);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 주기 유형별 기본 schedule_config(2장). 세부 설정은 추후 설정 화면에서 조정.
  Map<String, dynamic> _defaultConfig(ScheduleType type) {
    final now = DateTime.now();
    switch (type) {
      case ScheduleType.weekly:
      case ScheduleType.biweekly:
        return {'weekday': now.weekday, 'time': '10:00'};
      case ScheduleType.monthly:
        return {'day': now.day};
      case ScheduleType.yearly:
        return {'month': now.month, 'day': now.day};
      case ScheduleType.fixedDates:
      case ScheduleType.manual:
        return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('새 기록 시작')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('무엇을 기록할까요?', style: text.titleMedium),
          const SizedBox(height: 4),
          Text('예: 우리 가족, 첫째 아이',
              style: text.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: '프로젝트 이름',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _canSubmit ? _create() : null,
          ),
          const SizedBox(height: 28),
          Text('얼마나 자주 찍을까요?', style: text.titleMedium),
          const SizedBox(height: 12),
          _ScheduleSelector(
            value: _scheduleType,
            onChanged: (v) => setState(() => _scheduleType = v),
          ),
          const SizedBox(height: 28),
          Text('특별한 날에 묶을까요? (선택)', style: text.titleMedium),
          const SizedBox(height: 12),
          _EventPegSelector(
            value: _eventPeg,
            onChanged: (v) => setState(() => _eventPeg = v),
          ),
          const SizedBox(height: 36),
          FilledButton(
            onPressed: _canSubmit ? _create : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('시작하기'),
          ),
        ],
      ),
    );
  }
}

class _ScheduleSelector extends StatelessWidget {
  const _ScheduleSelector({required this.value, required this.onChanged});
  final ScheduleType value;
  final ValueChanged<ScheduleType> onChanged;

  static const _labels = {
    ScheduleType.weekly: '매주',
    ScheduleType.biweekly: '격주',
    ScheduleType.monthly: '매월',
    ScheduleType.yearly: '매년',
    ScheduleType.fixedDates: '지정일',
    ScheduleType.manual: '직접',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ScheduleType.values.map((t) {
        return ChoiceChip(
          label: Text(_labels[t]!),
          selected: value == t,
          onSelected: (_) => onChanged(t),
        );
      }).toList(),
    );
  }
}

class _EventPegSelector extends StatelessWidget {
  const _EventPegSelector({required this.value, required this.onChanged});
  final EventPeg value;
  final ValueChanged<EventPeg> onChanged;

  static const _labels = {
    EventPeg.none: '없음',
    EventPeg.birthday: '생일',
    EventPeg.holiday: '명절',
    EventPeg.season: '계절',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: EventPeg.values.map((e) {
        return ChoiceChip(
          label: Text(_labels[e]!),
          selected: value == e,
          onSelected: (_) => onChanged(e),
        );
      }).toList(),
    );
  }
}

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
  // 주기 기준일(엔진 reminder_time이 config로 읽음). 기본은 오늘 기준이지만
  // 사용자가 직접 고를 수 있다: 매주=요일, 매월=며칠, 매년=몇 월·며칠.
  final Set<int> _weekdays = {DateTime.now().weekday}; // 매주(다중), 1=월~7=일
  int _dayOfMonth = DateTime.now().day; // 매월·매년 공통 '며칠'
  int _month = DateTime.now().month; // 매년 '몇 월'
  final List<DateTime> _fixedDates = []; // '직접' 선택 시 고른 촬영 날짜들
  final Set<EventPeg> _eventPegs = {}; // 다중 선택(비어 있으면 '없음')
  DateTime? _birthday; // 주인공 생일(선택, 아이디어1 나이 라벨용)
  bool _pushEnabled = true; // 선택한 주기/특별한 날 푸시 알림 받기
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _titleController.text.trim().isNotEmpty &&
      !_saving &&
      // '직접' 주기인데 날짜를 하나도 안 고르면 알림 설정이 깨지므로 막는다.
      (_scheduleType != ScheduleType.fixedDates || _fixedDates.isNotEmpty) &&
      // '매주'인데 요일을 하나도 안 고르면 알림이 안 잡히므로 막는다.
      (_scheduleType != ScheduleType.weekly || _weekdays.isNotEmpty);

  Future<void> _create() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    if (_scheduleType == ScheduleType.fixedDates && _fixedDates.isEmpty) return;
    setState(() => _saving = true);
    try {
      // 푸시 on/off를 schedule_config에 보관 → 재예약 때도 사용자 선택을 따른다.
      final config = _defaultConfig(_scheduleType)..['push'] = _pushEnabled;
      // '직접'은 사용자가 고른 날짜들을 저장(그날 아침 10시 알림).
      if (_scheduleType == ScheduleType.fixedDates) {
        config['dates'] =
            _fixedDates.map((d) => d.toIso8601String()).toList();
      }
      final project = await ref.read(projectRepositoryProvider).create(
            title: title,
            scheduleType: _scheduleType,
            scheduleConfig: config,
            eventPegs: _eventPegs,
          );

      // 생일(선택) 저장 — 사진 나이 라벨 + 생일 페그 알림 날짜로 사용.
      if (_birthday != null) {
        await ref
            .read(appSettingsProvider.notifier)
            .setProjectBirthday(project.id, _birthday);
      }

      // 푸시를 켰을 때만 권한을 요청하고 예약한다(동의 받는 시점에 요청, 3·9장).
      final notifications = ref.read(notificationServiceProvider);
      if (_pushEnabled) {
        await notifications.requestPermission();
      }
      await notifications
          .scheduleForProject(project, const [], birthday: _birthday);

      if (mounted) Navigator.of(context).pop<Project>(project);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  /// '직접' 주기: 달력에서 촬영 날짜를 골라 목록에 추가(중복 방지·정렬).
  Future<void> _addFixedDate() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      helpText: '촬영할 날짜',
    );
    if (picked == null) return;
    final d = DateTime(picked.year, picked.month, picked.day);
    if (!_fixedDates.contains(d)) {
      setState(() {
        _fixedDates
          ..add(d)
          ..sort();
      });
    }
    _unfocusSoon();
  }

  /// '특별한 날' 생일 칩 토글. 생일은 날짜가 있어야 알림이 예약되므로
  /// (notification_service: birthday != null 조건), 칩을 켜는 순간 주인공 생일
  /// 날짜가 없으면 그 자리에서 날짜를 받고, 취소하면 칩도 켜지 않는다 →
  /// '생일 챙기기'를 골랐는데 조용히 무효가 되던 허점을 막는다.
  Future<void> _toggleEventPeg(EventPeg peg) async {
    FocusScope.of(context).unfocus();
    final adding = !_eventPegs.contains(peg);
    if (adding && peg == EventPeg.birthday && _birthday == null) {
      await _pickBirthday();
      if (_birthday == null) return; // 날짜를 안 고르면 생일 칩은 켜지 않는다.
    }
    setState(() {
      if (adding) {
        _eventPegs.add(peg);
      } else {
        _eventPegs.remove(peg);
      }
    });
  }

  Future<void> _pickBirthday() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? now,
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      helpText: '주인공 생일',
    );
    if (picked != null) setState(() => _birthday = picked);
    _unfocusSoon();
  }

  /// 달력 등 모달을 닫으면 FocusScope가 직전 포커스(제목 입력창)를 복원해
  /// autofocus 자판이 다시 열린다. 다음 프레임에 포커스를 거둬 이를 막는다.
  void _unfocusSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusScope.of(context).unfocus();
    });
  }

  /// 주기 유형별 기본 schedule_config(2장). 푸시는 모두 **아침 10시**.
  /// 세부 설정은 추후 설정 화면에서 조정.
  Map<String, dynamic> _defaultConfig(ScheduleType type) {
    switch (type) {
      case ScheduleType.daily:
        return {'time': '10:00'};
      case ScheduleType.weekly:
        return {'weekdays': _weekdays.toList()..sort(), 'time': '10:00'};
      case ScheduleType.biweekly:
        return {
          'weekday': _weekdays.isEmpty ? DateTime.now().weekday : _weekdays.first,
          'time': '10:00',
        };
      case ScheduleType.monthly:
        return {'day': _dayOfMonth, 'time': '10:00'};
      case ScheduleType.yearly:
        return {'month': _month, 'day': _dayOfMonth, 'time': '10:00'};
      case ScheduleType.fixedDates:
      case ScheduleType.manual:
        return {'time': '10:00'};
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('새 기록 시작')),
      // 이름 입력 외의 곳(빈 여백·라벨)을 누르면 포커스를 거둬 자판을 내린다.
      // 칩/스위치처럼 자체 탭을 먹는 위젯은 각 콜백에서 따로 unfocus 한다.
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
          Text('무엇을 기록할까요?', style: text.titleMedium),
          const SizedBox(height: 4),
          Text('예: 우리 가족, 첫째 아이, 여행, 생일',
              style: text.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: '기록 이름',
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
            onChanged: (v) {
              FocusScope.of(context).unfocus();
              setState(() => _scheduleType = v);
            },
          ),
          // 주기 기준일 선택 — 언제를 기준으로 알릴지 사용자가 직접 고른다.
          if (_scheduleType == ScheduleType.weekly) ...[
            const SizedBox(height: 12),
            _WeekdayPicker(
              selected: _weekdays,
              onToggle: (v) => setState(() {
                // 다중 선택. 마지막 하나는 남겨 요일 0개가 되지 않게.
                if (_weekdays.contains(v)) {
                  if (_weekdays.length > 1) _weekdays.remove(v);
                } else {
                  _weekdays.add(v);
                }
              }),
            ),
          ],
          if (_scheduleType == ScheduleType.monthly) ...[
            const SizedBox(height: 12),
            _DayOfMonthPicker(
              label: '매월 며칠에 찍을까요?',
              value: _dayOfMonth,
              onChanged: (v) => setState(() => _dayOfMonth = v),
            ),
          ],
          if (_scheduleType == ScheduleType.yearly) ...[
            const SizedBox(height: 12),
            _MonthPicker(
              value: _month,
              onChanged: (v) => setState(() => _month = v),
            ),
            const SizedBox(height: 12),
            _DayOfMonthPicker(
              label: '며칠에?',
              value: _dayOfMonth,
              onChanged: (v) => setState(() => _dayOfMonth = v),
            ),
          ],
          if (_scheduleType == ScheduleType.manual) ...[
            const SizedBox(height: 8),
            Text(
              '정해진 알림 없이 원할 때 찍어요. 생일 같은 특별한 날만 챙기려면 '
              '아래 ‘선택 항목 더보기’에서 골라주세요.',
              style: text.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
          if (_scheduleType == ScheduleType.fixedDates) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in _fixedDates)
                  InputChip(
                    label: Text(_fmtDate(d)),
                    onDeleted: () => setState(() => _fixedDates.remove(d)),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.calendar_month, size: 18),
                  label: const Text('날짜 추가'),
                  onPressed: _addFixedDate,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _fixedDates.isEmpty
                  ? '고른 날 아침 10시에 알려드려요. (안 고르면 자유롭게 촬영)'
                  : '고른 ${_fixedDates.length}일에 아침 10시 알림을 보내드려요',
              style: text.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 16),
          // 선택 항목(특별한 날·생일·알림)을 처음부터 펼쳐 보여준다.
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: true,
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 4, bottom: 8),
              title: const Text('선택 항목 더보기'),
              subtitle: Text('특별한 날 · 생일 · 알림',
                  style: text.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('특별한 날도 챙겨볼까요?', style: text.titleMedium),
                ),
                const SizedBox(height: 12),
                _EventPegSelector(
                  selected: _eventPegs,
                  onToggle: _toggleEventPeg,
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('주인공 생일', style: text.titleMedium),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('넣으면 사진마다 나이가 자동으로 표시돼요',
                      style: text.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _pickBirthday,
                    icon: const Icon(Icons.cake_outlined),
                    label: Text(_birthday == null
                        ? '생일 선택'
                        : '${_birthday!.year}.${_birthday!.month.toString().padLeft(2, '0')}.${_birthday!.day.toString().padLeft(2, '0')}'),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    value: _pushEnabled,
                    onChanged: (v) {
                      FocusScope.of(context).unfocus();
                      setState(() => _pushEnabled = v);
                    },
                    title: const Text('알림 받기'),
                    subtitle: Text(
                      '선택한 주기와 특별한 날에 알림을 보내드릴까요?',
                      style: text.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // 시작하기 — 하단 고정 바가 아니라 여백을 두고 띄운 형태.
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 28),
            child: FilledButton(
              onPressed: _canSubmit ? _create : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('시작하기'),
            ),
          ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleSelector extends StatelessWidget {
  const _ScheduleSelector({required this.value, required this.onChanged});
  final ScheduleType value;
  final ValueChanged<ScheduleType> onChanged;

  // 화면에 노출할 주기(격주 제외). '직접'은 날짜를 골라 채우는 fixedDates,
  // '자유롭게'는 정기 알림 없는 manual(특별한 날만 챙기고 싶을 때).
  static const _shown = [
    ScheduleType.daily,
    ScheduleType.weekly,
    ScheduleType.monthly,
    ScheduleType.yearly,
    ScheduleType.fixedDates,
    ScheduleType.manual,
  ];
  static const _labels = {
    ScheduleType.daily: '매일',
    ScheduleType.weekly: '매주',
    ScheduleType.monthly: '매월',
    ScheduleType.yearly: '매년',
    ScheduleType.fixedDates: '직접',
    ScheduleType.manual: '자유롭게',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _shown.map((t) {
        return ChoiceChip(
          label: Text(_labels[t]!),
          selected: value == t,
          onSelected: (_) => onChanged(t),
        );
      }).toList(),
    );
  }
}

/// 이벤트 페그 다중 선택 — 생일·명절·계절을 동시에 고를 수 있다(아무것도 안 고르면 '없음').
class _EventPegSelector extends StatelessWidget {
  const _EventPegSelector({required this.selected, required this.onToggle});
  final Set<EventPeg> selected;
  final ValueChanged<EventPeg> onToggle;

  static const _options = [EventPeg.birthday, EventPeg.holiday, EventPeg.season];
  static const _labels = {
    EventPeg.birthday: '생일',
    EventPeg.holiday: '명절',
    EventPeg.season: '계절',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _options.map((e) {
        return FilterChip(
          label: Text(_labels[e]!),
          selected: selected.contains(e),
          onSelected: (_) => onToggle(e),
        );
      }).toList(),
    );
  }
}

/// 주기 기준일 선택 위젯들의 공통 왼쪽 정렬 라벨.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
      );
}

/// 매주: 무슨 요일에 찍을지(월~일 → weekday 1~7). 여러 요일 다중 선택 가능.
class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({required this.selected, required this.onToggle});
  final Set<int> selected;
  final ValueChanged<int> onToggle;
  static const _names = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('무슨 요일에 찍을까요? (여러 개 선택 가능)'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < 7; i++)
              FilterChip(
                label: Text(_names[i]),
                selected: selected.contains(i + 1),
                onSelected: (_) => onToggle(i + 1),
              ),
          ],
        ),
      ],
    );
  }
}

/// 매년: 몇 월에 찍을지(1~12월).
class _MonthPicker extends StatelessWidget {
  const _MonthPicker({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('몇 월에 찍을까요?'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var mth = 1; mth <= 12; mth++)
              ChoiceChip(
                label: Text('$mth월'),
                selected: value == mth,
                onSelected: (_) => onChanged(mth),
              ),
          ],
        ),
      ],
    );
  }
}

/// 매월/매년: 며칠에 찍을지(1~31). 그 날이 없는 달은 말일에 알림
/// (reminder_time._clampDay가 말일로 보정).
class _DayOfMonthPicker extends StatelessWidget {
  const _DayOfMonthPicker({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              isExpanded: true,
              items: [
                for (var d = 1; d <= 31; d++)
                  DropdownMenuItem(value: d, child: Text('$d일')),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
        if (value >= 29) ...[
          const SizedBox(height: 4),
          Text('$value일이 없는 달은 그 달 마지막 날에 알려드려요.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ],
    );
  }
}

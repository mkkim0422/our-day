import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../core/constants/enums.dart';
import '../../core/utils/event_peg_dates.dart';
import '../../core/utils/reminder_time.dart';
import '../../data/db/app_database.dart';

/// 알림 탭 시 전달되는 페이로드(어느 프로젝트의 어느 사진으로 진입할지).
class NotificationPayload {
  const NotificationPayload({
    required this.projectId,
    this.captureId,
    this.recap = false,
    this.recall = false,
  });

  final String projectId;
  final String? captureId;

  /// 연말 리캡 알림이면 true → 비교·타임랩스 화면으로 진입(아이디어6).
  final bool recap;

  /// 회상 알림(기념일·장소)이면 true → 그 추억 사진을 먼저 보여주고
  /// 거기서 "같은 구도로 한 컷"으로 잇는다(곧장 카메라로 가지 않음).
  final bool recall;

  String encode() =>
      jsonEncode({'p': projectId, 'c': captureId, 'r': recap, 'm': recall});

  static NotificationPayload? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final pid = map['p'] as String?;
      if (pid == null) return null;
      return NotificationPayload(
        projectId: pid,
        captureId: map['c'] as String?,
        recap: map['r'] as bool? ?? false,
        recall: map['m'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }
}

/// 로컬 알림 서비스 (6장 리텐션 — 이벤트 페그·회상형 알림).
///
/// 플랫폼 의존(권한·채널·타임존)을 이 서비스 뒤로 격리한다(8장). 화면/리포지토리는
/// 이 인터페이스만 사용. 사진을 외부로 보내지 않으며 알림은 전부 기기 로컬에서 예약된다(9장).
class NotificationService {
  NotificationService();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'reminders';
  static const _channelName = '촬영 리마인더';
  static const _channelDesc = '이번 기간 한 컷·회상 알림';

  /// iOS 64개 한도와 배터리를 고려해 회상 알림 예약 수를 제한(5장 우선순위 관리 원칙 준용).
  static const _maxNostalgia = 8;

  bool _ready = false;

  /// 앱 시작 시 1회 호출(main). 타임존 DB·플러그인 초기화 + 탭 핸들러 등록.
  Future<void> init({
    void Function(NotificationPayload payload)? onTap,
  }) async {
    if (_ready) return;

    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // 타임존 조회 실패 시 UTC로 폴백(예약은 동작, 시각만 보정 안 됨).
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      // 권한은 사용자 흐름에서 명시적으로 요청(앱 첫 진입에 강요하지 않음).
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: darwin),
      onDidReceiveNotificationResponse: (resp) {
        final payload = NotificationPayload.decode(resp.payload);
        if (payload != null) onTap?.call(payload);
      },
    );
    _ready = true;
  }

  /// 앱이 알림 탭으로 시작됐는지(콜드 스타트). 있으면 그 페이로드 반환.
  Future<NotificationPayload?> initialLaunchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return NotificationPayload.decode(details?.notificationResponse?.payload);
  }

  /// 알림 권한 요청(Android 13+ / iOS). 사용자 흐름에서 호출.
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
          alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    return false;
  }

  /// 프로젝트의 알림을 (재)예약한다. 기존 것을 지우고 다시 건다(중복 방지).
  ///
  /// - 이벤트 페그/주기 알림: 다음 기간 1건.
  /// - 회상 알림: 과거 촬영들의 다가오는 기념일 중 가까운 순으로 최대 [_maxNostalgia]건.
  Future<void> scheduleForProject(
    Project project,
    List<Capture> captures, {
    DateTime? now,
    DateTime? birthday,
  }) async {
    if (!_ready) return;
    final from = now ?? DateTime.now();
    await cancelForProject(project.id);

    // 푸시 옵트아웃: 사용자가 이 기록의 알림을 끈 경우(scheduleConfig.push == false)
    // 기존 예약만 지우고 새로 걸지 않는다.
    if (project.scheduleConfig['push'] == false) return;

    // ① 주기 알림.
    final due = ReminderTime.nextPeriodReminder(
        project.scheduleType, project.scheduleConfig, from);
    if (due != null) {
      await _zonedSchedule(
        id: _periodId(project.id),
        title: _periodTitle(project),
        body: '오늘 «${project.title}» 한 컷 어때요? 같은 포즈로 그날의 우리를 남겨요.',
        when: due,
        payload: NotificationPayload(projectId: project.id),
      );
    }

    // ② 회상 알림(다가오는 기념일 순).
    //    같은 월·일에 찍은 사진이 여러 장이면 한 건으로 묶어 같은 날 중복 발송을 막는다.
    //    대표는 가장 최근(가장 가까운 해)의 사진 → "작년 오늘" 문구가 우선되도록.
    final byDay = <String, ({Capture capture, DateTime when})>{};
    for (final c in captures) {
      final when = ReminderTime.nextAnniversary(c.capturedAt, from);
      final key = '${when.year}-${when.month}-${when.day}';
      final existing = byDay[key];
      if (existing == null ||
          c.capturedAt.isAfter(existing.capture.capturedAt)) {
        byDay[key] = (capture: c, when: when);
      }
    }
    final anniversaries = byDay.values.toList()
      ..sort((a, b) => a.when.compareTo(b.when));

    for (var i = 0; i < anniversaries.length && i < _maxNostalgia; i++) {
      final a = anniversaries[i];
      final years = a.when.year - a.capture.capturedAt.year;
      await _zonedSchedule(
        id: _nostalgiaId(project.id, i),
        title: '그날의 우리',
        body: years <= 1
            ? '작년 오늘, 가족은 이런 모습이었어요. 다시 한 컷 남겨볼까요?'
            : '$years년 전 오늘의 기록이 있어요. 같은 포즈로 다시 찍어봐요.',
        when: a.when,
        payload: NotificationPayload(
            projectId: project.id, captureId: a.capture.id, recall: true),
      );
    }

    // ③ 연말 자동 리캡(아이디어6, 6장 7번): 12/31 저녁, 올해 기록이 2컷↑이면
    //    "올해의 우리" 타임랩스를 보러 오게 하는 알림.
    final thisYearCount =
        captures.where((c) => c.capturedAt.year == from.year).length;
    if (thisYearCount >= 2) {
      var recap = DateTime(from.year, 12, 31, 19);
      if (recap.isBefore(from)) recap = DateTime(from.year + 1, 12, 31, 19);
      await _zonedSchedule(
        id: _recapId(project.id),
        title: '올해의 우리 🎞️',
        body: '«${project.title}» 올해 기록이 모였어요. 한 해의 변화를 타임랩스로 돌아볼까요?',
        when: recap,
        payload: NotificationPayload(projectId: project.id, recap: true),
      );
    }

    // ④ 이벤트 페그 알림(생일·명절·계절) — 각 페그의 다음 발생일 아침 10시.
    await _scheduleEventPegs(project, from, birthday);
  }

  /// 선택된 이벤트 페그별 다음 알림을 예약한다(다중 선택 가능).
  /// - 생일: 선택한 생일 월·일.  - 명절: 다음 설날/추석.  - 계절: 다음 계절 첫날.
  Future<void> _scheduleEventPegs(
    Project project,
    DateTime from,
    DateTime? birthday,
  ) async {
    final pegs = _pegsOf(project);

    if (pegs.contains(EventPeg.birthday) && birthday != null) {
      await _zonedSchedule(
        id: _birthdayPegId(project.id),
        title: '오늘은 우리 기념일 🎂',
        body: '«${project.title}» 생일이에요. 같은 포즈로 한 컷 남겨볼까요?',
        when: EventPegDates.nextBirthday(birthday, from),
        payload: NotificationPayload(projectId: project.id),
      );
    }

    if (pegs.contains(EventPeg.holiday)) {
      final when = EventPegDates.nextHoliday(from);
      if (when != null) {
        await _zonedSchedule(
          id: _holidayPegId(project.id),
          title: '명절, 가족이 모인 날 🏡',
          body: '온 가족이 모인 오늘, «${project.title}» 한 컷 어때요?',
          when: when,
          payload: NotificationPayload(projectId: project.id),
        );
      }
    }

    if (pegs.contains(EventPeg.season)) {
      await _zonedSchedule(
        id: _seasonPegId(project.id),
        title: '계절이 바뀌었어요 🍃',
        body: '새 계절의 첫날, «${project.title}» 한 컷으로 변화를 남겨요.',
        when: EventPegDates.nextSeasonStart(from),
        payload: NotificationPayload(projectId: project.id),
      );
    }
  }

  /// 프로젝트의 이벤트 페그 집합(단일 컬럼 + scheduleConfig.eventPegs 다중 보관).
  Set<EventPeg> _pegsOf(Project project) {
    final set = <EventPeg>{};
    if (project.eventPeg != EventPeg.none) set.add(project.eventPeg);
    final raw = project.scheduleConfig['eventPegs'];
    if (raw is List) {
      for (final n in raw) {
        final match = EventPeg.values.where((e) => e.name == '$n');
        if (match.isNotEmpty) set.add(match.first);
      }
    }
    return set;
  }

  /// 위치 기반 회상 알림을 **즉시** 표시 (5장).
  ///
  /// 그 장소에 다시 왔을 때 "여기, 그때 우리" + 예전 사진으로 진입하게 한다.
  /// 탭하면 [latest](그 장소의 최근 촬영)를 오버레이 기준으로 촬영 화면에 진입
  /// (payload의 captureId → RootScreen 라우팅 → 같은 구도 재촬영).
  Future<void> showPlaceRecall({
    required Place place,
    required Capture latest,
    required String projectId,
  }) async {
    if (!_ready) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(
      id: _placeRecallId(place.id),
      title: '여기, 그때 우리 📍',
      body: '«${place.label}»에서 찍은 추억이 있어요. 같은 구도로 다시 한 컷 남겨볼까요?',
      notificationDetails: details,
      payload: NotificationPayload(
              projectId: projectId, captureId: latest.id, recall: true)
          .encode(),
    );
  }

  /// 이 프로젝트가 예약한 알림 전부 취소.
  Future<void> cancelForProject(String projectId) async {
    if (!_ready) return;
    await _plugin.cancel(id: _periodId(projectId));
    await _plugin.cancel(id: _recapId(projectId));
    await _plugin.cancel(id: _birthdayPegId(projectId));
    await _plugin.cancel(id: _holidayPegId(projectId));
    await _plugin.cancel(id: _seasonPegId(projectId));
    for (var i = 0; i < _maxNostalgia; i++) {
      await _plugin.cancel(id: _nostalgiaId(projectId, i));
    }
  }

  // --- 내부 ---

  Future<void> _zonedSchedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required NotificationPayload payload,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload.encode(),
    );
  }

  String _periodTitle(Project project) {
    switch (project.eventPeg) {
      case EventPeg.birthday:
        return '오늘은 기념할 날 🎂';
      case EventPeg.holiday:
        return '명절, 가족이 모인 날 🏡';
      case EventPeg.season:
        return '계절이 바뀌었어요 🍃';
      case EventPeg.none:
        return '이번 기간 한 컷 📸';
    }
  }

  // 알림 ID: 프로젝트별 결정적 분배(주기 1건 + 회상 N건이 안 겹치게).
  int _periodId(String projectId) => (projectId.hashCode & 0x7fffffff) % 1000000;
  int _nostalgiaId(String projectId, int index) =>
      1000000 + ((projectId.hashCode & 0x7fffffff) % 1000000) * 10 + index;
  // 장소 회상 알림 ID — 예약 알림 ID 영역과 겹치지 않게 별도 범위.
  int _placeRecallId(String placeId) =>
      20000000 + (placeId.hashCode & 0x7fffffff) % 1000000;
  // 연말 리캡 ID — 또 다른 별도 범위.
  int _recapId(String projectId) =>
      30000000 + (projectId.hashCode & 0x7fffffff) % 1000000;
  // 이벤트 페그 ID — 페그별 별도 범위(생일/명절/계절).
  int _birthdayPegId(String projectId) =>
      40000000 + (projectId.hashCode & 0x7fffffff) % 1000000;
  int _holidayPegId(String projectId) =>
      50000000 + (projectId.hashCode & 0x7fffffff) % 1000000;
  int _seasonPegId(String projectId) =>
      60000000 + (projectId.hashCode & 0x7fffffff) % 1000000;
}

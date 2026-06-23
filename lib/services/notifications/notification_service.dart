import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../core/constants/enums.dart';
import '../../core/utils/reminder_time.dart';
import '../../data/db/app_database.dart';

/// 알림 탭 시 전달되는 페이로드(어느 프로젝트의 어느 사진으로 진입할지).
class NotificationPayload {
  const NotificationPayload({required this.projectId, this.captureId});

  final String projectId;
  final String? captureId;

  String encode() => jsonEncode({'p': projectId, 'c': captureId});

  static NotificationPayload? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final pid = map['p'] as String?;
      if (pid == null) return null;
      return NotificationPayload(projectId: pid, captureId: map['c'] as String?);
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
  }) async {
    if (!_ready) return;
    final from = now ?? DateTime.now();
    await cancelForProject(project.id);

    // ① 주기/이벤트 페그 알림.
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
    final anniversaries = captures
        .map((c) => (capture: c, when: ReminderTime.nextAnniversary(c.capturedAt, from)))
        .toList()
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
        payload:
            NotificationPayload(projectId: project.id, captureId: a.capture.id),
      );
    }
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
      payload: NotificationPayload(projectId: projectId, captureId: latest.id)
          .encode(),
    );
  }

  /// 이 프로젝트가 예약한 알림 전부 취소.
  Future<void> cancelForProject(String projectId) async {
    if (!_ready) return;
    await _plugin.cancel(id: _periodId(projectId));
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
}

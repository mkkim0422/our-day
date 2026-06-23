import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'camera/photo_storage.dart';
import 'notifications/notification_service.dart';

/// 서비스 계층 의존성 주입(riverpod).
///
/// 카메라(`CameraService`)는 화면 수명주기에 묶이므로 화면 내부에서 생성하고,
/// 무상태 서비스만 여기서 provider로 제공한다.

final photoStorageProvider = Provider<PhotoStorage>((ref) => PhotoStorage());

/// 로컬 알림 서비스(단일 인스턴스). main에서 init() 후 화면들이 공유.
final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());

/// 알림 탭으로 진입할 대상(페이로드). RootScreen이 구독해 촬영 화면으로 보낸다.
/// (riverpod 3.x는 StateProvider가 기본 export에서 빠져 Notifier로 구현.)
class PendingNotification extends Notifier<NotificationPayload?> {
  @override
  NotificationPayload? build() => null;

  void set(NotificationPayload? payload) => state = payload;
  void clear() => state = null;
}

final pendingNotificationProvider =
    NotifierProvider<PendingNotification, NotificationPayload?>(
        PendingNotification.new);

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/repositories/providers.dart';
import 'backup/cloud_backup_service.dart';
import 'backup/google_drive_backup_service.dart';
import 'backup/local_backup_service.dart';
import 'camera/photo_storage.dart';
import 'location/location_service.dart';
import 'notifications/notification_service.dart';
import 'settings/app_settings.dart';
import 'share/share_service.dart';
import 'timelapse/timelapse_service.dart';

/// 서비스 계층 의존성 주입(riverpod).
///
/// 카메라(`CameraService`)는 화면 수명주기에 묶이므로 화면 내부에서 생성하고,
/// 무상태 서비스만 여기서 provider로 제공한다.

final photoStorageProvider = Provider<PhotoStorage>((ref) => PhotoStorage());

/// 타임랩스(애니메이션 GIF) 생성 서비스 (⑤·⑥장).
final timelapseServiceProvider =
    Provider<TimelapseService>((ref) => TimelapseService());

/// 공유 / 내보내기 서비스 (⑥장).
final shareServiceProvider =
    Provider<ShareService>((ref) => const ShareService());

/// 로컬 백업(zip) 서비스 (③·8장). DB 인스턴스를 주입받는다.
final localBackupServiceProvider = Provider<LocalBackupService>(
  (ref) => LocalBackupService(ref.watch(databaseProvider)),
);

/// 클라우드 백업(1차: 구글 드라이브). 추상화 뒤에 둬서 애플 iCloud 추가 시 교체.
/// 로컬 백업이 만든 동일 .zip을 사용자 본인 클라우드(무료 용량)에 올린다.
final cloudBackupServiceProvider = Provider<CloudBackupService>((ref) {
  final svc = GoogleDriveBackupService();
  ref.onDispose(svc.dispose);
  return svc;
});

/// 위치 서비스 (5장). 기본은 geolocator 구현.
final locationServiceProvider =
    Provider<LocationService>((ref) => const GeolocatorLocationService());

/// 앱 설정(파일 저장) — 위치 회상 opt-in·장소별 마지막 알림 시각 등(5장).
final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsController, AppSettingsData>(
        AppSettingsController.new);

class AppSettingsController extends AsyncNotifier<AppSettingsData> {
  AppSettingsStore? _store;

  @override
  Future<AppSettingsData> build() async {
    final dir = await getApplicationDocumentsDirectory();
    final store = AppSettingsStore(File(p.join(dir.path, 'settings.json')));
    _store = store;
    return store.load();
  }

  Future<void> setLocationRecallEnabled(bool enabled) async {
    final current = state.value ?? const AppSettingsData();
    final next = current.copyWith(locationRecallEnabled: enabled);
    await _store?.save(next);
    state = AsyncData(next);
  }

  /// 장소 회상 알림을 띄운 시각 기록(빈도 제한용).
  Future<void> recordPlaceNotified(String placeId, DateTime at) async {
    final current = state.value ?? const AppSettingsData();
    final map = Map<String, DateTime>.from(current.placeLastNotified)
      ..[placeId] = at;
    final next = current.copyWith(placeLastNotified: map);
    await _store?.save(next);
    state = AsyncData(next);
  }

  /// 프로젝트 주인공 생일 설정/해제(아이디어1 — 나이 라벨).
  Future<void> setProjectBirthday(String projectId, DateTime? birthday) async {
    final current = state.value ?? const AppSettingsData();
    final map = Map<String, DateTime>.from(current.projectBirthdays);
    if (birthday == null) {
      map.remove(projectId);
    } else {
      map[projectId] = birthday;
    }
    final next = current.copyWith(projectBirthdays: map);
    await _store?.save(next);
    state = AsyncData(next);
  }

  /// 온보딩 샘플 시드 완료 표시(중복 시드 방지).
  Future<void> markSampleSeeded() async {
    final current = state.value ?? const AppSettingsData();
    final next = current.copyWith(sampleSeeded: true);
    await _store?.save(next);
    state = AsyncData(next);
  }

  /// 첫 실행 샘플 타임랩스 쇼케이스 확인 완료 표시.
  Future<void> markShowcaseSeen() async {
    final current = state.value ?? const AppSettingsData();
    final next = current.copyWith(showcaseSeen: true);
    await _store?.save(next);
    state = AsyncData(next);
  }

  /// 촬영 오버레이 코치(반투명 겹침 설명) 확인 완료 표시.
  Future<void> markCaptureCoachSeen() async {
    final current = state.value ?? const AppSettingsData();
    if (current.captureCoachSeen) return;
    final next = current.copyWith(captureCoachSeen: true);
    await _store?.save(next);
    state = AsyncData(next);
  }

  /// 앱 잠금 PIN 해시 설정(null이면 잠금 해제).
  Future<void> setLockPin(String? pinHash) async {
    final current = state.value ?? const AppSettingsData();
    final next = pinHash == null
        ? current.copyWith(clearLockPin: true)
        : current.copyWith(lockPinHash: pinHash);
    await _store?.save(next);
    state = AsyncData(next);
  }

  /// 촬영별 키(cm) 기록 설정/해제(아이디어8 — 성장 차트).
  Future<void> setCaptureHeight(String captureId, double? cm) async {
    final current = state.value ?? const AppSettingsData();
    final map = Map<String, double>.from(current.captureHeights);
    if (cm == null) {
      map.remove(captureId);
    } else {
      map[captureId] = cm;
    }
    final next = current.copyWith(captureHeights: map);
    await _store?.save(next);
    state = AsyncData(next);
  }
}

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

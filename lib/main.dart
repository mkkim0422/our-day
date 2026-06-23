import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // riverpod 전역 스코프(상태관리 통일, 1장). 알림 탭을 provider로 흘려보내기 위해
  // 컨테이너를 직접 만들어 main에서 초기화한 뒤 UncontrolledProviderScope로 주입.
  final container = ProviderContainer();

  final notifications = container.read(notificationServiceProvider);
  await notifications.init(
    onTap: (payload) =>
        container.read(pendingNotificationProvider.notifier).set(payload),
  );
  // 콜드 스타트(알림 탭으로 앱 실행)도 동일 경로로 처리.
  final launch = await notifications.initialLaunchPayload();
  if (launch != null) {
    container.read(pendingNotificationProvider.notifier).set(launch);
  }

  runApp(UncontrolledProviderScope(
    container: container,
    child: const OurDayApp(),
  ));
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:our_day/app.dart';
import 'package:our_day/data/db/app_database.dart';
import 'package:our_day/features/home/home_providers.dart';
import 'package:our_day/services/providers.dart';
import 'package:our_day/services/settings/app_settings.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

/// 첫 실행 시드/쇼케이스 게이트를 통과한 상태로 고정(환영 화면 바로 노출).
class _SeededSettings extends AppSettingsController {
  @override
  Future<AppSettingsData> build() async =>
      const AppSettingsData(sampleSeeded: true, showcaseSeen: true);
}

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('widget_test');
    PathProviderPlatform.instance = _FakePathProvider(temp.path);
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  testWidgets('프로젝트가 없으면 환영 화면과 시작 버튼이 보인다', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectsProvider.overrideWith((ref) => Stream.value(<Project>[])),
          appSettingsProvider.overrideWith(_SeededSettings.new),
        ],
        child: const OurDayApp(),
      ),
    );
    // 인트로 애니메이션(약 2.1초)과 전환을 통과시킨다.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('그날 우리'), findsWidgets);
    expect(find.text('시작하기'), findsOneWidget);
  });
}

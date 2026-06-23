import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:our_day/app.dart';
import 'package:our_day/data/db/app_database.dart';
import 'package:our_day/features/home/home_providers.dart';

void main() {
  testWidgets('프로젝트가 없으면 환영 화면과 시작 버튼이 보인다', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // drift 스트림(위젯 테스트 FakeAsync에서 타이머 잔류) 대신 빈 목록 주입.
        overrides: [
          projectsProvider.overrideWith((ref) => Stream.value(<Project>[])),
        ],
        child: const OurDayApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('그날 우리'), findsOneWidget);
    expect(find.text('시작하기'), findsOneWidget);
  });
}

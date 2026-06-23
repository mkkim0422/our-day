import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:our_day/services/settings/app_settings.dart';
import 'package:path/path.dart' as p;

void main() {
  group('AppSettingsData JSON', () {
    test('라운드트립(토글 + 장소별 알림 시각)', () {
      final data = AppSettingsData(
        locationRecallEnabled: true,
        placeLastNotified: {'place-1': DateTime(2026, 6, 23, 12, 30)},
      );
      final restored = AppSettingsData.fromJson(data.toJson());

      expect(restored.locationRecallEnabled, isTrue);
      expect(restored.placeLastNotified['place-1'], DateTime(2026, 6, 23, 12, 30));
    });

    test('기본값(없는 키)은 안전하게 처리', () {
      final restored = AppSettingsData.fromJson(const {});
      expect(restored.locationRecallEnabled, isFalse);
      expect(restored.placeLastNotified, isEmpty);
    });
  });

  group('AppSettingsStore', () {
    late Directory temp;

    setUp(() => temp = Directory.systemTemp.createTempSync('settings_test'));
    tearDown(() => temp.deleteSync(recursive: true));

    test('없는 파일은 기본값을 반환', () async {
      final store = AppSettingsStore(File(p.join(temp.path, 'settings.json')));
      final data = await store.load();
      expect(data.locationRecallEnabled, isFalse);
    });

    test('save 후 load 라운드트립', () async {
      final file = File(p.join(temp.path, 'settings.json'));
      final store = AppSettingsStore(file);

      await store.save(const AppSettingsData(locationRecallEnabled: true));
      expect(file.existsSync(), isTrue);

      final reloaded = await AppSettingsStore(file).load();
      expect(reloaded.locationRecallEnabled, isTrue);
    });

    test('손상된 파일은 기본값으로 복구', () async {
      final file = File(p.join(temp.path, 'settings.json'))
        ..writeAsStringSync('{ not valid json');
      final data = await AppSettingsStore(file).load();
      expect(data.locationRecallEnabled, isFalse);
    });
  });
}

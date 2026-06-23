import 'dart:convert';
import 'dart:io';

/// 앱 설정 데이터(파일 저장). DB 스키마 마이그레이션 없이 가벼운 토글·상태를 보관.
///
/// - [locationRecallEnabled]: 위치 기반 회상 알림 opt-in(5장 — 기본 꺼짐).
/// - [placeLastNotified]: 장소별 마지막 회상 알림 시각(빈도 제한용).
class AppSettingsData {
  const AppSettingsData({
    this.locationRecallEnabled = false,
    this.placeLastNotified = const {},
  });

  final bool locationRecallEnabled;
  final Map<String, DateTime> placeLastNotified;

  AppSettingsData copyWith({
    bool? locationRecallEnabled,
    Map<String, DateTime>? placeLastNotified,
  }) =>
      AppSettingsData(
        locationRecallEnabled:
            locationRecallEnabled ?? this.locationRecallEnabled,
        placeLastNotified: placeLastNotified ?? this.placeLastNotified,
      );

  Map<String, dynamic> toJson() => {
        'locationRecallEnabled': locationRecallEnabled,
        'placeLastNotified': placeLastNotified
            .map((k, v) => MapEntry(k, v.toIso8601String())),
      };

  factory AppSettingsData.fromJson(Map<String, dynamic> json) {
    final raw = (json['placeLastNotified'] as Map?) ?? const {};
    final parsed = <String, DateTime>{};
    raw.forEach((k, v) {
      final d = DateTime.tryParse('$v');
      if (d != null) parsed['$k'] = d;
    });
    return AppSettingsData(
      locationRecallEnabled: json['locationRecallEnabled'] as bool? ?? false,
      placeLastNotified: parsed,
    );
  }
}

/// [AppSettingsData]를 JSON 파일로 읽고 쓴다(documents/settings.json).
class AppSettingsStore {
  AppSettingsStore(this._file);

  final File _file;

  Future<AppSettingsData> load() async {
    if (!await _file.exists()) return const AppSettingsData();
    try {
      final json = jsonDecode(await _file.readAsString());
      return AppSettingsData.fromJson(json as Map<String, dynamic>);
    } catch (_) {
      // 손상 시 기본값으로 복구(앱이 죽지 않게).
      return const AppSettingsData();
    }
  }

  Future<void> save(AppSettingsData data) async {
    if (!await _file.parent.exists()) {
      await _file.parent.create(recursive: true);
    }
    await _file.writeAsString(jsonEncode(data.toJson()));
  }
}

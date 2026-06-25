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
    this.projectBirthdays = const {},
    this.captureHeights = const {},
    this.sampleSeeded = false,
    this.showcaseSeen = false,
    this.captureCoachSeen = false,
    this.lockPinHash,
  });

  final bool locationRecallEnabled;
  final Map<String, DateTime> placeLastNotified;

  /// 프로젝트별 주인공 생일(아이디어1 — 나이 라벨). projectId → 생일.
  final Map<String, DateTime> projectBirthdays;

  /// 촬영별 키(cm) 기록(아이디어8 — 성장 차트). captureId → cm.
  final Map<String, double> captureHeights;

  /// 온보딩 샘플 데이터를 이미 심었는지(중복 시드 방지).
  final bool sampleSeeded;

  /// 첫 실행 샘플 타임랩스 쇼케이스를 이미 봤는지.
  final bool showcaseSeen;

  /// 촬영 화면의 오버레이(반투명 겹침) 설명 코치를 이미 봤는지.
  final bool captureCoachSeen;

  /// 앱 잠금 PIN의 해시(null이면 잠금 꺼짐). 평문은 저장하지 않는다.
  final String? lockPinHash;

  bool get appLockEnabled => lockPinHash != null;

  AppSettingsData copyWith({
    bool? locationRecallEnabled,
    Map<String, DateTime>? placeLastNotified,
    Map<String, DateTime>? projectBirthdays,
    Map<String, double>? captureHeights,
    bool? sampleSeeded,
    bool? showcaseSeen,
    bool? captureCoachSeen,
    String? lockPinHash,
    bool clearLockPin = false,
  }) =>
      AppSettingsData(
        locationRecallEnabled:
            locationRecallEnabled ?? this.locationRecallEnabled,
        placeLastNotified: placeLastNotified ?? this.placeLastNotified,
        projectBirthdays: projectBirthdays ?? this.projectBirthdays,
        captureHeights: captureHeights ?? this.captureHeights,
        sampleSeeded: sampleSeeded ?? this.sampleSeeded,
        showcaseSeen: showcaseSeen ?? this.showcaseSeen,
        captureCoachSeen: captureCoachSeen ?? this.captureCoachSeen,
        lockPinHash: clearLockPin ? null : (lockPinHash ?? this.lockPinHash),
      );

  Map<String, dynamic> toJson() => {
        'locationRecallEnabled': locationRecallEnabled,
        'placeLastNotified': placeLastNotified
            .map((k, v) => MapEntry(k, v.toIso8601String())),
        'projectBirthdays':
            projectBirthdays.map((k, v) => MapEntry(k, v.toIso8601String())),
        'captureHeights': captureHeights,
        'sampleSeeded': sampleSeeded,
        'showcaseSeen': showcaseSeen,
        'captureCoachSeen': captureCoachSeen,
        'lockPinHash': lockPinHash,
      };

  factory AppSettingsData.fromJson(Map<String, dynamic> json) {
    Map<String, DateTime> parseDates(Object? raw) {
      final map = (raw as Map?) ?? const {};
      final out = <String, DateTime>{};
      map.forEach((k, v) {
        final d = DateTime.tryParse('$v');
        if (d != null) out['$k'] = d;
      });
      return out;
    }

    final rawHeights = (json['captureHeights'] as Map?) ?? const {};
    final heights = <String, double>{};
    rawHeights.forEach((k, v) {
      final d = (v is num) ? v.toDouble() : double.tryParse('$v');
      if (d != null) heights['$k'] = d;
    });

    return AppSettingsData(
      locationRecallEnabled: json['locationRecallEnabled'] as bool? ?? false,
      placeLastNotified: parseDates(json['placeLastNotified']),
      projectBirthdays: parseDates(json['projectBirthdays']),
      captureHeights: heights,
      sampleSeeded: json['sampleSeeded'] as bool? ?? false,
      showcaseSeen: json['showcaseSeen'] as bool? ?? false,
      captureCoachSeen: json['captureCoachSeen'] as bool? ?? false,
      lockPinHash: json['lockPinHash'] as String?,
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

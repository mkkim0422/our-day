import 'package:drift/drift.dart';

import '../../core/constants/enums.dart';
import 'converters.dart';

/// drift 테이블 정의 (2장 데이터 모델).
///
/// 원칙: 이미지 원본/썸네일은 파일시스템에 저장하고, DB에는 **경로·메타데이터만** 보관.
/// enum은 `textEnum`(이름 문자열)으로 저장 → 스키마 안정성.

/// Account — 소셜 로그인 + 본인 클라우드 백업 연결용. 자체 비밀번호 없음(9장).
class Accounts extends Table {
  TextColumn get id => text()(); // PK (provider uid 기반)
  TextColumn get provider => textEnum<AccountProvider>()();
  TextColumn get displayName => text().nullable()();
  TextColumn get backupTarget =>
      textEnum<BackupTarget>().withDefault(const Constant('none'))();
  DateTimeColumn get lastBackupAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Project — 하나의 "기록 주제"(예: 우리 가족, 첫째 아이).
class Projects extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get title => text()();
  TextColumn get scheduleType => textEnum<ScheduleType>()();

  /// 주기 유형별 상세(2장 "촬영 주기 설정"). 예: {"weekday":6,"time":"10:00"}.
  TextColumn get scheduleConfig =>
      text().map(const JsonMapConverter()).withDefault(const Constant('{}'))();

  TextColumn get coverPhotoId => text().nullable()();
  TextColumn get eventPeg =>
      textEnum<EventPeg>().withDefault(const Constant('none'))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Member — 프로젝트 구성원(아이디어7 — 구성원 태깅·필터).
class Members extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get role => text().nullable()(); // 엄마/아빠/첫째 등

  @override
  Set<Column> get primaryKey => {id};
}

/// CaptureMember — 촬영↔구성원 N:N 태깅(아이디어7). "이 사진에 누가 있는지".
class CaptureMembers extends Table {
  TextColumn get captureId =>
      text().references(Captures, #id, onDelete: KeyAction.cascade)();
  TextColumn get memberId =>
      text().references(Members, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {captureId, memberId};
}

/// Capture — 촬영 1건. 4가지 입력 경로 결과가 모두 이 1건으로 저장(②-1).
///
/// `project_id` + `captured_at` 시계열 조회가 잦아 복합 인덱스를 둔다.
@TableIndex(name: 'idx_capture_project_time', columns: {#projectId, #capturedAt})
class Captures extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();

  /// 인쇄 품질 위해 원본은 고해상도 보존, 썸네일과 분리 보관(7-1장).
  TextColumn get filePath => text()();
  TextColumn get thumbPath => text()();

  DateTimeColumn get capturedAt => dateTime()();
  TextColumn get periodLabel => text()(); // 표시용 (예: "2026 · 6월")

  /// 정렬 보정값(이동/스케일/회전) — 사후 재정렬·타임랩스 흔들림 감소용(4장).
  TextColumn get alignmentMeta =>
      text().map(const JsonMapConverter()).nullable()();

  TextColumn get note => text().nullable()();
  TextColumn get placeId =>
      text().nullable().references(Places, #id, onDelete: KeyAction.setNull)();
  TextColumn get backupState =>
      textEnum<BackupState>().withDefault(const Constant('localOnly'))();

  /// 꾸미기 결과 이미지 경로(있으면 기록에서 이 버전을 보여줌). 원본(filePath)은
  /// 타임랩스·오버레이용으로 그대로 보존(꾸미기 v3).
  TextColumn get decoratedPath => text().nullable()();

  /// 사용자가 그리드에서 직접 정한 표시·재생 순서(작을수록 앞=최신 쪽).
  /// null이면 촬영일 기준 자동 정렬. 길게 눌러 드래그로 재배치하면 채워진다.
  IntColumn get sortIndex => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Place — 사진을 찍은 의미 있는 장소(5장 위치 기반 회상 알림 기준).
class Places extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get label => text()(); // 역지오코딩 또는 사용자 입력
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  IntColumn get radiusM => integer().withDefault(const Constant(200))();
  IntColumn get captureCount => integer().withDefault(const Constant(0))();
  BoolColumn get geofenceEnabled =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

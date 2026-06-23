/// 앱 전역 공용 enum (2장 데이터 모델).
///
/// drift 테이블은 이 enum들을 `textEnum`(이름 문자열)으로 저장한다.
/// → 인덱스 기반 저장보다 스키마 안정적(순서 바뀌어도 안전).
library;

/// 소셜 로그인 제공자. 자체 비밀번호 없음(9장).
enum AccountProvider { google, apple }

/// 백업 대상. 안드로이드=드라이브, iOS=iCloud (8장 추상화).
enum BackupTarget { googleDrive, icloud, none }

/// 개별 항목(사진/DB)의 백업 상태.
enum BackupState { localOnly, backedUp, pending }

/// 촬영 주기 유형(2장). 상세는 `schedule_config`(json)에서 처리.
enum ScheduleType { weekly, biweekly, monthly, yearly, fixedDates, manual }

/// 촬영을 묶을 이벤트(6장 리텐션 — 이벤트 페그 알림).
enum EventPeg { none, birthday, holiday, season }

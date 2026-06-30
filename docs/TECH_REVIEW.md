# 출시 기술점검 결과 (체크리스트 8번)

> 점검 2026-07-01 · 대상: 현재 main · 빌드 검증: `flutter build appbundle --release`

## 점검 항목

| 항목 | 상태 | 내용 |
|---|---|---|
| 패키지명(applicationId) | ✅ | `com.ourday.our_day` 고정 |
| minSdk | ✅ | 26 (Android 8.0) — 인수인계 기준 |
| targetSdk | ✅ | `flutter.targetSdkVersion`(Flutter SDK 기본=최신 추적). Play 최소 요건 충족 |
| compileSdk | ✅ | `flutter.compileSdkVersion` |
| versionName / versionCode | ✅ | 1.0.0 / 1 (pubspec `1.0.0+1`). 업데이트마다 versionCode 증가 필요 |
| 16KB 페이지 정렬(Android 15) | ✅ | 최신 AGP/NDK(Flutter 제공)로 자동 처리. 네이티브 .so 는 플러그인 제공분만 |
| 난독화/축소(R8) | ✅ | `isMinifyEnabled=true` + `isShrinkResources=true` + proguard-rules.pro |
| 릴리스 서명 | ⚠️→틀 완성 | key.properties 있으면 정식 키, 없으면 디버그 폴백. **제출 전 정식 키 필수** |
| 코어 라이브러리 디슈가링 | ✅ | desugar_jdk_libs 2.1.4 (flutter_local_notifications 요구) |

## 권한 점검 (불필요 권한 제거)

매니페스트의 모든 권한이 **실제 코드에서 사용** 됨 — 제거 대상 없음.

| 권한 | 사용처(코드) | 비고 |
|---|---|---|
| INTERNET | google_fonts 다운로드, 드라이브 백업 | 필수 |
| CAMERA | 오버레이 정렬 카메라 | `required=false`(태블릿 호환) |
| POST_NOTIFICATIONS | notification_service.dart | Android 13+ |
| RECEIVE_BOOT_COMPLETED | 재부팅 후 알림 재예약 | |
| ACCESS_FINE/COARSE_LOCATION | location_service.dart (회상 알림, opt-in) | **Play 민감권한 선언 필요**(체크리스트 15) |
| READ_MEDIA_IMAGES | photo_manager 백필/스토리 | Android 13+ |
| READ_EXTERNAL_STORAGE | 동상, `maxSdkVersion=32` | 구버전 분기 |
| ACCESS_MEDIA_LOCATION | photo_date.dart, backfill_screen.dart (EXIF GPS) | 스토리 '여행' 분류 |

## 외부 SDK / 데이터 전송

- 광고 SDK: **없음**(google_mobile_ads 미연동) — v1 광고 없음 확정과 일치.
- 분석/크래시 SDK: **없음**(Firebase/Analytics/Crashlytics 미연동).
- 유일한 외부 전송: Google Fonts(HTTPS), 사용자가 켠 구글 드라이브 백업(HTTPS).
- → Data Safety 양식(DATA_SAFETY_FORM.md)과 **모순 없음**.

## 남은 조치 (제가 못 하는 것)

- 릴리스 키스토어 생성 + key.properties (회장님) → 그 후 정식 서명 AAB 재빌드.
- 릴리스 SHA-1 을 OAuth 클라이언트에 등록(체크리스트 6).

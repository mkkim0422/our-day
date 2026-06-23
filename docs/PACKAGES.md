# 패키지 결정 기록 (1단계 산출물)

> 인수인계서 1장·10장 지시에 따라 각 패키지의 최신/유지보수 상태를 점검하고 확정한 결과.
> 점검일 기준: 2026-06. Flutter 3.41.6 / Dart 3.11.4 stable.

## 확정 — 즉시 채택 (pubspec에 추가 완료)

| 용도 | 패키지 | 채택 버전 | 비고 |
|---|---|---|---|
| 상태관리 | `flutter_riverpod` | 3.3.2 | bloc 대신 riverpod로 통일(보일러플레이트 적음) |
| 로컬 DB | `drift` (+`sqlite3_flutter_libs`) | 2.34.0 | sqflite보다 타입세이프·마이그레이션 우수 |
| DB 코드생성 | `drift_dev`, `build_runner` (dev) | 2.34.x / 2.15.0 | |
| 파일 경로 | `path_provider`, `path` | 최신 | 원본/썸네일 분리 저장 |
| 카메라 | `camera` | 0.12.0+1 | 오버레이 정렬 카메라 핵심 |
| 이미지 처리 | `image` | 4.9.1 | 오버레이 합성·리사이즈·정렬 보정 |
| 갤러리 불러오기 | `image_picker` | 1.2.2 | 입력경로 2·3 (갤러리/backfill) |
| 로컬 알림 | `flutter_local_notifications` (+`timezone`) | 22.0.1 | 이벤트페그·회상형 알림 |
| 공유 | `share_plus` | 최신 | |
| 권한 | `permission_handler` | 최신 | 카메라·알림·위치 단계적 요청 |
| 위치 | `geolocator` | 14.0.3 | 좌표 취득·역지오코딩 보조 |
| 유틸 | `uuid`, `intl` | 최신 | PK 생성, 기간 라벨 포맷 |

## 보류 — 해당 기능 단계에서 추가 (이유 명시)

| 용도 | 후보 | 상태/결정 | 추가 시점 |
|---|---|---|---|
| **타임랩스(이미지→영상)** | ~~`ffmpeg_kit_flutter`~~ → **순수 Dart `image`(GIF)** | ✅ **작업 #6 결정**: 원본 ffmpeg-kit는 2025-01-06 공식 폐기(바이너리 2025-04 내림). 커뮤니티 포크 `ffmpeg_kit_flutter_new`는 **GPL**이라 상용 배포에 부담, 네이티브 인코더는 플랫폼별 구현 비용 큼 → **MVP는 추가 의존성 없이 `image` 패키지로 애니메이션 GIF 생성**(네이티브 코드 0, 양 플랫폼 동일, 단톡방·SNS 호환). 한계는 256색·용량. 고화질 mp4가 필요해지면 `TimelapseService`의 프레임 합성 파이프라인 뒤에 네이티브 인코더(MediaCodec/AVAssetWriter)를 끼워 교체(별도 작업). | 작업 #6 ✅ |
| **지오펜싱(백그라운드 위치)** | **`native_geofence`** | 네이티브 CLLocationManager/GeofencingClient 래핑, 배터리 효율적, iOS14+/Android23+. 인수인계서 배터리·한도 우려에 부합. Kotlin **1.9.25+** 필요. opt-in 강제. | 작업 #8 |
| 소셜 로그인 | `google_sign_in`, `sign_in_with_apple` | 표준. 백업 스코프(드라이브)와 함께 추가. | 작업 #7 |
| 클라우드 백업 | `googleapis`(Drive) + iCloud(파일기반) | 백업 서비스 인터페이스 뒤로 격리(8장). | 작업 #7 |
| 광고 | `google_mobile_ads` (+UMP 동의) | 아동·가족 정책 필터 필수(6-1장). 슬롯 컴포넌트로 격리. | 작업 #9 |
| 인앱결제/구독 | `in_app_purchase` | 광고제거 프리미엄. 실물상품(v2 인쇄)은 외부 PG. | 작업 #9 / v2 |

## 원칙
- 패키지는 deprecate 가능 → 각 단계 착수 시 재점검.
- 플랫폼 의존 패키지(카메라·알림·위치·백업)는 `services/` 인터페이스 뒤로 격리(8장).

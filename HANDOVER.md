# 그날 우리 (Our Day) — 인수인계서

> 작성일 2026-06-29 · 앱 버전 1.0.0+1 · Flutter(Dart 3.11+) · applicationId `com.ourday.our_day`
> 이 문서는 코드 전수 조사를 바탕으로 작성됨. 파일 경로를 명시했으니 항상 코드를 1차 근거로 볼 것.

---

## 1. 한눈 요약

- **무엇을 위한 앱인가**: 가족(아이)을 **같은 구도·같은 포즈로 주기적으로(예: 매달 한 컷) 촬영**해서, 시간이 지나며 쌓인 사진을 **타임랩스·"그때 vs 지금" 비교**로 보여 주는 가족 성장 기록 앱. 슬로건 "매달 한 컷, 그날의 우리".
- **핵심 가치**: ① 촬영 시 **직전 사진을 반투명으로 겹쳐 보여 주는 정렬 오버레이**(킬러 기능) → 누구나 같은 구도로 찍게. ② 쌓인 기록을 **타임랩스/비교/포스터**로 변환해 "변화 체감".
- **데이터 정책**: **로컬 우선(Local-First)**. 모든 사진·데이터는 기기에 저장, 자체 서버 전송 없음. 클라우드 백업은 향후(현재 미연동), 로컬 ZIP 백업은 구현됨.
- **플랫폼**: Android(실기 검증 대상: Galaxy S926N) + iOS 대비 설계. 다크모드는 고정 라이트(파스텔 톤).

---

## 2. 사용자 여정 (첫 실행 → 일상 사용)

1. **인트로 스플래시** (`features/intro/intro_screen.dart`): 로고+슬로건 애니메이션(2.1초, 탭 스킵).
2. **샘플 쇼케이스** (`features/intro/sample_showcase_screen.dart`): 첫 실행 시 샘플 가족 5컷이 폴라로이드 타임랩스로 돌며 "이렇게 쌓여요"를 보여 줌. **"내 기록 시작하기" → 곧바로 새 기록 만들기 화면**으로 진입(중간 환영 화면 생략).
3. **새 기록 만들기** (`features/onboarding/new_project_screen.dart`): 기록 이름 + 촬영 주기(매일/매주/매월/매년/직접) 선택. 생일·특별한 날·알림은 **"선택 항목 더보기"로 접혀** 있어 30초 내 생성 가능.
4. **프로젝트 셸(홈)** (`features/home/project_shell.dart`): 상단 2탭 = **앨범 / 변화 보기**, 우상단 ⋮ 메뉴(예전 사진 채우기 / 앨범 설정), 항상 보이는 **촬영 FAB**.
5. **일상**: 알림이 오면 촬영 → 정렬 오버레이로 같은 구도로 한 컷 → 저장. 사진이 2컷 이상 쌓이면 **변화 보기**(타임랩스/비교) 가능.
6. **여러 기록**: 앨범 허브(`features/home/album_hub_screen.dart`)에서 여러 프로젝트(가족/첫째/여행 등)를 카드로 전환.

---

## 3. 기능 전체 목록 (영역별)

### 3.1 촬영 (`features/capture/`)
- **정렬 오버레이 카메라** (`capture_screen.dart`): 직전/기준/장소 사진을 뷰파인더에 **반투명 합성**(투명도 슬라이더), 3분할 가이드 그리드, 줌·탭포커스·플래시·전후면 전환, **셀프 타이머(0/3/5/10초)**. 첫 오버레이 등장 시 1회성 코치(오류 오해 방지).
- **촬영 직후 확인/정렬** (`alignment_adjuster_screen.dart`): 기본은 **바로 "저장"**(정렬은 선택). 원하면 "직전 사진에 맞추기(선택)"로 이동·확대·회전 미세 조정 → 보정값을 `AlignmentMeta`로 저장(원본 이미지는 변형 없이 고해상도 보존). **그날의 한마디(메모)를 이 화면에서 바로 입력** 가능(선택).
- **4가지 입력 경로**: ① 직접 촬영 ② 카메라 화면의 갤러리 아이콘 ③ **백필(예전 사진 일괄 채우기)** ④ 알림 탭 진입.
- **백필** (`backfill_screen.dart`): 갤러리에서 여러 장 선택 → 주기에 맞춰 과거 날짜 자동 배치(개별 날짜 수정 가능) → 일괄 저장.
- **사진 상세** (`capture_detail_screen.dart`): PageView 스와이프, 기간·나이·메모·키(cm)·구성원 표시/편집, 꾸미기 진입.

### 3.2 변화 보기 (`features/compare/`)
- **비교/타임랩스** (`compare_screen.dart`): "N컷의 타임랩스" 인앱 재생 + **타임랩스 GIF 공유/기기에 저장**, "그때 vs 지금" 비교 카드(첫↔최신, 나이 라벨), **구성원 필터**(특정 인물 사진만). "더 보기" 메뉴: 비교 이미지 공유/**저장**, 밀어서 변화 보기, 성장 포스터, 성장 차트.
- **타임랩스 플레이어** (`widgets/timelapse_player.dart`): 크로스페이드/즉시 전환 토글, 재생·정지.
- **밀어서 변화 보기**(스크러버, `compare_screen.dart` 내 `ScrubberScreen`): 슬라이더로 두 시점을 겹쳐 모핑.
- **성장 포스터** (`collage_poster_screen.dart`): 모든 컷을 격자 포스터로 묶어 PNG **공유/기기 저장**.
- **성장 차트** (`growth_chart_screen.dart`): 사진별 키(cm)를 꺾은선 그래프(CustomPainter)로, **공유/기기 저장**.

### 3.3 홈 위젯 (`features/home/widgets/`)
- **진척 게이지 + 스트릭** (`progress_gauge.dart`): 누적 컷 수 + **최근 12개 기간 채움 점 스트립**(모든 주기 유형) + **🔥 연속 N회 스트릭 칩**(2회 이상일 때만, "끊김에 관대한" 응원형 — 이번 기간 미촬영은 안 끊음).
- **마일스톤 카드** (`milestone_card.dart`): 생일이 설정된 프로젝트에서 **백일·첫 돌·N살** 도달 시, 그 시점 근처(±31일) 사진과 함께 홈 상단에 축하 카드 → 탭하면 타임랩스로 이동. (계산: `core/utils/milestone.dart`)
- **변화 보기 카드**(home_screen 내 `_SeeChangesCard`): 2컷 이상이면 노출.
- **타임라인 그리드** (`timeline_grid.dart`): 모든 기록 썸네일 그리드. **사진을 길게 누르면 정렬 모드(셀 흔들림) → 드래그로 순서 변경 → 완료**. 바뀐 순서는 `Captures.sortIndex`에 저장되어 **그리드·타임랩스·비교 모든 곳에 반영**.

### 3.4 꾸미기 (`features/decorate/`) — 프리미엄 성격
- 스킨 선택(`skin.dart`, 12 카테고리 × 5 = 60종) → 프레임(8)·배경(12)·필터(20)·폰트(google_fonts)·스티커(16 모티프, `decor_motifs.dart`)·성장 데이터(나이/키)를 입혀 PNG 내보내기. 원본은 보존하고 꾸민 버전 경로(`decoratedPath`)만 저장.

### 3.5 구성원 (`features/members/`)
- 프로젝트별 구성원(이름/역할) 관리(`members_screen.dart`), 사진에 N:N 태깅, 비교에서 인물 필터.

### 3.6 설정 (`features/settings/`)
- 전역 설정(`settings_screen.dart`): 위치 회상 on/off, **앱 잠금(4자리 PIN, SHA256)**, 개인정보처리방침, 라이선스, 문의(help@sphinfo.co.kr), 버전.
- 앨범별 설정(`album_settings_screen.dart`): 주인공 생일(나이 라벨/마일스톤용), 구성원 관리 진입.
- 앱 잠금(`app_lock.dart`): `LockGate`/`LockScreen`, 5회 실패 시 점증 쿨다운, 콜드스타트마다 재잠금.

### 3.7 알림 (`services/notifications/notification_service.dart`)
- **주기 촬영 알림**: 주기 시작 시각(기본 아침 10시)에 "이번 기간 한 컷".
- **회상(기념일) 알림**: 과거 사진의 같은 월·일에 "그날의 추억".
- **연말 리캡**: 12/31 저녁, 올해 기록 2개 이상이면 비교/타임랩스로 유도.
- **이벤트 페그**: 생일/명절(설·추석, 2025~2035 표)/계절 시작(`core/utils/event_peg_dates.dart`).
- **위치 회상**: 의미 있는 장소 근처 도착 시 그 장소의 예전 사진(아래 3.8).

### 3.8 위치 회상 (`services/location/`)
- 촬영 시 opt-in이면 GPS 좌표로 `Place` 생성/재사용. 앱 복귀 시 현재 위치가 장소 반경 안이고 쿨다운(기본 6시간) 지났으면 회상 알림(`place_recall.dart`, 순수 판정 로직). "항상 허용"은 강요하지 않고 전경(whileInUse)만. 플랫폼 지오펜스 한도 대응으로 촬영 많은 상위 N개만 활성.

### 3.9 공유/저장·백업
- **공유/기기 저장** (`services/share/share_service.dart`): OS 공유 시트(`share_plus`) + **사진첩 저장**(`gal`, '그날 우리' 앨범). RepaintBoundary→PNG 캡처로 한글 라벨/워터마크 정확히 내보냄.
- **로컬 백업/복원** (`services/backup/`): DB manifest(JSON) + 사진 원본/썸네일/꾸민사진 + **settings.json(생일·키·앱잠금·토글)**을 ZIP 한 개로 묶음(`local_backup_service.dart`, `database_backup.dart`, manifest formatVersion 2 — 구성원·태그·decoratedPath·sortIndex까지 **누수 없이** 포함). 설정 화면에서 **백업 만들기 / 공유(내보내기) / 외부 .zip 불러와 복원 / 백업 삭제** 제공(`file_selector`로 외부 파일 선택). 복원은 기존 데이터를 교체(replace)하며, 복원 후 앱 재시작 권장.

### 3.10 광고 (`ads/ad_slot.dart`)
- 현재 빈 슬롯(AdMob 미연동). `AdPlacement`: `homeBanner`, `albumNative`, `timelapseDoneInterstitial`.
- 정책: 촬영 화면·비교(감정의 정점)·회상 알림에는 광고 금지. 홈 하단 배너/앨범 네이티브/타임랩스 생성완료 직후 전면만 허용.

---

## 4. 데이터 모델 (`lib/data/db/`)

테이블 정의 `tables.dart`, DB 클래스 `app_database.dart`(현재 **schemaVersion 4**), JSON 변환 `converters.dart`.

| 테이블 | 핵심 컬럼 | 비고 |
|---|---|---|
| **Projects** | id(uuid), title, scheduleType, scheduleConfig(JSON), coverPhotoId, eventPeg, createdAt | 기록 주제. 주기 상세는 JSON |
| **Captures** | id, projectId(FK), filePath, thumbPath, capturedAt, periodLabel, alignmentMeta(JSON?), note?, placeId(FK?), backupState, decoratedPath?, **sortIndex?** | 촬영 1건. 원본/썸네일 분리, 정렬 보정·꾸민 경로·**사용자 순서** 보관 |
| **Members** | id, projectId(FK), name, role? | 구성원 |
| **CaptureMembers** | captureId(FK), memberId(FK) | 사진↔구성원 N:N 태깅 |
| **Places** | id, projectId(FK), label, lat, lng, radiusM, captureCount, geofenceEnabled | 위치 회상 기준 장소 |
| **Accounts** | id, provider, displayName?, backupTarget, lastBackupAt? | 소셜/백업 연결(현재 미연동) |

**마이그레이션 이력** (`app_database.dart`의 `MigrationStrategy`):
- v2: 구성원 태깅(CaptureMembers) 추가
- v3: 꾸미기 결과 경로(`decoratedPath`) 추가
- v4: 사용자 정렬 순서(`sortIndex`) 추가 — null이면 촬영일순, 값 있으면 그 순서

**Repository** (`lib/data/repositories/`): project / capture / member / place / account. 의존성 주입은 `repositories/providers.dart`.
- 사진 목록은 `CaptureRepository.watchByProject` 가 `sortIndex ASC, capturedAt DESC` 로 정렬(수동 순서 우선, 없으면/새 사진은 최신 먼저).

---

## 5. 아키텍처 & 디렉토리

```
Presentation (lib/features/*)
  ↓  Riverpod providers (상태·DI)
Repositories (lib/data/repositories/*)
  ↓
Drift DB (lib/data/db/*)  +  Services (lib/services/*)
  ↓
로컬 파일시스템 (원본/썸네일/백업 ZIP/설정 JSON)
```

- **상태관리**: flutter_riverpod 3.x. Provider(서비스), StreamProvider(실시간 목록), FutureProvider(1회 조회), AsyncNotifierProvider(앱 설정), NotifierProvider(앱 잠금 등).
- **플랫폼 의존 격리**(테스트·이식 용이): CameraService, LocationService, NotificationService, ShareService, PhotoStorage.
- **무거운 작업은 isolate**(`compute`): 썸네일 리사이즈, GIF 인코딩, 타임존.
- **핵심 유틸**(`lib/core/`): `schedule_period`(기간 키/라벨/최근기간), `reminder_time`(다음 알림시각), `event_peg_dates`(생일/명절/계절), `age_label`(나이 라벨), `milestone`(백일/돌/N살), `backfill_dates`, `geo_distance`(Haversine). enum은 `core/constants/enums.dart`(ScheduleType, EventPeg, BackupState, BackupTarget, AccountProvider). 테마 `core/theme/app_theme.dart`(로즈핑크 #D86A92 / 크림라일락 #F8F2F7, 고정 라이트).
- **브랜딩**: `branding/app_logo.dart`(CustomPainter 로고).

---

## 6. 기술 스택 (`pubspec.yaml` 주요)

| 패키지 | 용도 |
|---|---|
| flutter_riverpod | 상태관리·DI |
| drift + sqlite3_flutter_libs + drift_dev | 로컬 DB(ORM)·코드생성 |
| camera | 정렬 오버레이 카메라 |
| image | 디코딩/리사이즈/GIF 생성 |
| image_picker | 갤러리 선택(백필) |
| gal | 사진첩(갤러리) 저장 |
| photo_manager | 갤러리 미디어 접근 |
| share_plus | OS 공유 시트 |
| flutter_local_notifications + timezone + flutter_timezone | 로컬 알림·타임존 |
| geolocator | 위치(회상 알림) |
| permission_handler | 권한 요청 |
| archive | ZIP 백업 |
| google_fonts | 꾸미기 폰트 |
| crypto | PIN SHA256 |
| uuid / path_provider / intl | 식별자/경로/국제화 |

빌드 도구: build_runner, drift_dev, flutter_lints, flutter_launcher_icons.

---

## 7. 빌드 · 실행 · 검증

```bash
flutter pub get
dart run build_runner build      # drift 스키마 변경 시 코드 재생성 (필수)
flutter analyze                  # 정적 분석 (현재 클린)
flutter test                     # 단위/위젯 테스트 (현재 69개 통과)
flutter build apk --release      # 릴리즈 APK (약 95MB)
adb -s <device> install -r build/app/outputs/flutter-apk/app-release.apk
```

- **DB 스키마(`tables.dart`)를 바꾸면 반드시** `app_database.dart`의 schemaVersion 증가 + 마이그레이션 추가 + `build_runner build`.
- 릴리즈 빌드는 logcat에서 debugPrint가 제거됨(디버깅은 profile/debug 빌드 권장).
- 테스트 위치 `test/` (예: `test/core/p2_milestone_streak_test.dart` — 마일스톤/기간 계산).

---

## 8. 권한 & 개인정보 (`android/app/src/main/AndroidManifest.xml`)

CAMERA(촬영), POST_NOTIFICATIONS·RECEIVE_BOOT_COMPLETED(알림/재부팅 복원), ACCESS_FINE/COARSE_LOCATION(위치 회상, 전경만), READ_MEDIA_IMAGES·READ_EXTERNAL_STORAGE(갤러리), INTERNET(google_fonts).
- 권한은 기능 사용 시점에 요청. "항상 허용" 위치는 요청하지 않음. PIN은 평문 미저장(SHA256).

---

## 9. 알려진 제약 · 주의점

- **에뮬레이터 합성 입력(adb input) 한계**: 카메라 화면(CameraPreview 플랫폼뷰), 시스템 사진 선택기, 스크롤뷰 안의 **길게 누르기/드래그**는 adb 합성 탭/홀드가 잘 안 먹는다(실손가락은 정상). → 촬영 직후 화면(정렬·메모)·타임라인 길게눌러 재배치 등은 **실기기로 검증**할 것. 화면 좌표는 스크린샷을 0.5배로 줄여(×2 매핑) 잡으면 편함.
- **비슷한 구도 사진 찾기 기능은 폐기됨**(무료 온디바이스로 비현실적). 재요청 시 구도매칭 재시도 대신 "같은 사람 얼굴 모으기(face embedding)"를 제안할 것.
- 타임랩스는 프레임 60장 상한(균등 샘플링)으로 OOM 방지. 출력은 GIF(고화질 MP4는 향후).
- **로컬 백업/복원은 구현됨**(설정 화면). 단 **클라우드 백업·소셜 로그인·AdMob은 미연동**(스캐폴드만 존재). 백업 방식(구글드라이브 vs 자체서버/NAS)은 미결정 — 개발자 메모리 `our-day-backup-decision` 참조.
- **win32 의존성 주의**: `share_plus`(win32 ^6)와 일부 파일 선택 패키지(win32 ^5)가 충돌. `file_picker` 대신 **`file_selector`** 사용(win32 6 호환). 파일 선택 패키지 교체 시 Android 빌드에서 `dart.library.ffi` 경로로 Windows 코드가 컴파일되므로 win32 버전 호환을 반드시 `flutter build apk`로 확인할 것.

---

## 10. 최근 변경 이력 (2026-06-28~29, UX 재설계)

코드 정밀조사 + 분석 근거로 진행. 커밋 단위로 정리:
1. **비슷사진 기능 전면 제거** — 관련 화면/서비스/테스트/의존성(tflite) 삭제, APK 125→95MB.
2. **P0 UX**: 정렬을 강제→선택, 첫 사진 확인 문구, "추억"→"변화 보기" 탭+카드, 완료 CTA 문구 정리, 라벨 있는 ⋮ 메뉴.
3. **P1 UX**: 결과물 **기기에 저장**(타임랩스/비교/포스터/차트), 촬영 후 **인라인 메모**, 첫 실행에서 중복 환영 화면 생략.
4. **P2 UX**: **연속 기록 스트릭 + 최근 기간 캘린더**(진척 게이지 일반화), **백일·돌 마일스톤 카드**.
5. **모든 기록 그리드 길게눌러 드래그 순서 변경**(sortIndex, 모든 곳 반영).

전 구간 `flutter analyze` 클린, 69개 테스트 통과. 자세한 진행 메모는 개발자 메모리(`uxredesign-p0-p1-p2`)에도 기록.

---

## 11. 향후 작업 후보

- 마일스톤 알림(백일·돌 전날 푸시) — 현재 알림은 주기/회상/연말리캡/이벤트페그(생일·명절·계절)만.
- 소셜 로그인(Google/Apple) + 클라우드 자동 백업(Drive/iCloud) — `account_repository`/`backup/*` 스캐폴드 활용. (로컬 백업/복원은 완료. 클라우드는 manifest/zip 재사용해 얹으면 됨.)
- 클라우드 용량 초과(구글 15GB 공용) 대응: 백업 화질 압축 옵션·증분 업로드·용량 사전확인 후 "로컬 내보내기로 폴백" 안내.
- AdMob 연동 — `ads/ad_slot.dart`, 빈도 상한.
- 배경 지오펜스 알림(ACCESS_BACKGROUND_LOCATION 별도 동의).
- 고화질 MP4 타임랩스(네이티브 인코더).

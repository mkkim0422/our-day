# 아키텍처 골격 (1단계 산출물)

인수인계서 1장(계층 분리) · 8장(플랫폼 격리) · 6-1장(광고 슬롯) · 7-1장(commerce 자리) 반영.

```
lib/
├─ main.dart              # 진입점 (ProviderScope)
├─ app.dart              # MaterialApp · 테마 · (작업#4에서 라우팅)
├─ core/
│  ├─ theme/             # 중립 디자인 테마 (8장: iOS 대비)
│  ├─ constants/         # 공용 enum·상수 (작업#2에서 채움)
│  └─ utils/             # 기간 계산·포맷 등
├─ data/                 # ← 작업#2
│  ├─ db/                # drift DB·테이블·DAO (사진은 파일, DB엔 경로·메타)
│  ├─ models/            # 도메인 모델 (Account/Project/Member/Capture/Place)
│  └─ repositories/      # repository 계층 (데이터 접근)
├─ services/             # 플랫폼 의존 격리 (8장) — 인터페이스+플랫폼별 구현
│  ├─ camera/            # 카메라 (작업#3)
│  ├─ notifications/     # 로컬 알림 (작업#5)
│  ├─ location/          # 위치·지오펜스 (작업#8)
│  ├─ backup/            # 백업 인터페이스 + 드라이브/iCloud 주입 (작업#7) ✅인터페이스 확정
│  └─ sharing/          # 공유 (작업#6)
├─ features/             # 화면 ①~⑥ (UI + riverpod 상태) — 작업#4~
│  ├─ onboarding/  home/  capture/  compare/  share/  settings/
├─ ads/                  # 광고 슬롯 컴포넌트 (6-1) ✅슬롯 분리 확정
└─ commerce/             # v2 인쇄·주문 자리 (7-1) — MVP 미구현, 구조만 격리
```

## 계층 의존 방향
`features(UI/상태)` → `data/repositories` → `data/db`·파일시스템
`features`·`repositories` → `services`(인터페이스) ← 플랫폼별 구현 주입

UI·비즈니스 로직은 플랫폼 무관 유지. OS별로 갈리는 코드는 전부 `services/` 뒤로.

## 확정 사항
- 상태관리: **riverpod** (`ProviderScope` 적용 완료)
- 디자인: Material 3 기반 중립 테마(테라코타 시드), iOS 이질감 최소화
- 백업: `BackupService` 인터페이스 확정 → 드라이브/iCloud 구현 주입 구조
- 광고: `AdSlot`(허용 placement만 enum으로 노출, 금지 위치는 구조적 차단)
- 라우팅(작업#4): `RootScreen`이 프로젝트 유무로 온보딩(①)/홈(②) 분기, 화면 전환은 Navigator 기반. ✅
- 부팅 확인: `flutter analyze` 무이슈, 테스트 10건 통과(인메모리 drift + 위젯 스모크)
```

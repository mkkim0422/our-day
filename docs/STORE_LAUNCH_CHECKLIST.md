# 그날 우리 — 스토어 출시 체크리스트 (순서대로)

작성: 2026-06-30. 태그 **[회장님]**=계정/결제/제출, **[제가]**=코드/문서/빌드, **[같이]**.

## 현재 기준선
- 앱 라벨 `그날 우리`, 패키지 `com.ourday.our_day`, version `1.0.0+1`, minSdk 26
- 광고 **미연동**(빈 슬롯)
- 릴리스 서명 = **틀 완성**(key.properties 있으면 정식 키, 없으면 디버그 폴백) → 정식 키 등록만 남음
- 난독화/축소(R8) = **활성화 완료**(`android/app/proguard-rules.pro`)
- 개인정보처리방침/삭제안내 = **공개용 HTML 작성 완료**(`docs/privacy-policy.html`, `docs/account-deletion.html`) → 호스팅만 남음
- 데이터 보안 양식 = **초안 완료**(`docs/DATA_SAFETY_FORM.md`)
- 클라우드 백업 = **앱 코드 완료**, OAuth 계정 설정만 남음 (`docs/CLOUD_BACKUP_SETUP.md`)

> **2026-07-01 진행분(제가, 계정 불필요)**: 서명 틀·난독화·기술점검·AAB 파이프라인·정책/삭제 페이지·데이터보안 초안 완료.
> 산출물: `BUILD_RELEASE.md`, `TECH_REVIEW.md`, `DATA_SAFETY_FORM.md`, `privacy-policy.html`, `account-deletion.html`, `android/key.properties.template`.

## 0단계 · 출시 범위 결정
- [ ] Android 먼저 / iOS 후속
- [ ] v1 광고 없이 (광고는 출시 후)
- [ ] 인앱결제 v1 제외
- [ ] 클라우드 백업 노출 범위(로컬 중심+클라우드 테스트사용자 한정 vs 민감스코프 검증)

## 1단계 · 계정·법무
- [ ] **[회장님]** Google Play Console 등록 $25 + 본인 인증
- [~] **[같이]** 개인정보처리방침 공개 URL — 전문 작성 완료(`privacy-policy.html`), **회장님 호스팅만**
- [~] **[같이]** 계정·데이터 삭제 경로/URL — 작성 완료(`account-deletion.html`), **회장님 호스팅만**

> **호스팅 원클릭(GitHub Pages)**: `docs/` 에 `index.html`+정책 2개 준비됨.
> GitHub repo → Settings → Pages → Source: `main` 브랜치 `/docs` 폴더 → Save.
> 몇 분 뒤 URL 발급: `https://<계정>.github.io/<repo>/privacy-policy.html`,
> `.../account-deletion.html` → 이 두 주소를 Play 콘솔 정책/삭제 URL 칸에 입력.
> (repo가 비공개면 Pages 공개 설정 필요. 노션/구글사이트로 HTML 붙여넣기도 가능.)

## 2단계 · 릴리스 빌드 하드닝
- [~] **[같이]** 릴리스 키스토어 — signingConfig 틀+template 완료, **회장님 키 생성만**(`key.properties.template`)
- [ ] **[회장님]** Play 앱 서명(Play App Signing)
- [ ] **[제가]** 릴리스 키 SHA-1을 OAuth 클라이언트에 추가 (키스토어 생성 후)
- [~] **[제가]** AAB 빌드 — 파이프라인 문서+디버그폴백 빌드 검증(`BUILD_RELEASE.md`). 정식 키로 재빌드만 남음
- [x] **[제가]** 기술점검: targetSdk·16KB·versionCode·권한·난독화 → `TECH_REVIEW.md` (불필요 권한 없음 확인)

## 3단계 · 스토어 자산·리스팅
- [x] **[제가]** 제목/짧은(80자)/긴 설명 (ASO 반영) → `STORE_LISTING.md`
- [ ] **[같이]** 스크린샷 2~8장 + 피처그래픽 1024×500 (아이콘 완료)
- [ ] **[회장님]** 카테고리·연락 이메일

## 4단계 · 컴플라이언스
- [~] **[같이]** 데이터 보안(Data Safety) 양식 — 초안 완료(`DATA_SAFETY_FORM.md`), **회장님 콘솔 입력만**
- [~] **[회장님]** 콘텐츠 등급 설문(IARC) — 답안 초안 완료(`STORE_COMPLIANCE_ANSWERS.md` §13), 콘솔 입력만
- [~] **[회장님]** 타깃 대상 = 성인(부모) — 권장답안·근거 완료(§14)
- [~] **[회장님]** 광고=없음 · 위치/사진 민감권한 사용 선언 — 선언문 초안 완료(§15)
- [~] **[같이]** 앱 액세스(리뷰어용 로그인 안내) — 안내문 초안 완료(§16)

## 5단계 · 클라우드/로그인
- [ ] **[회장님]** OAuth 클라이언트 등록 (릴리스 SHA-1 포함, `CLOUD_BACKUP_SETUP.md`)
- [ ] **[같이]** (공개 시) OAuth 동의화면 게시 + 민감스코프 검증 / v1 비공개면 생략

## 6단계 · 테스트 트랙 ⚠️ 일정 영향 최대
- [ ] **[제가]** 내부 테스트(Internal) 업로드·실기기 점검
- [ ] **[회장님]** 비공개 테스트 **12명 × 14일 연속** (신규 개인계정 프로덕션 자격) — 출시 2주+ 전 시작
- [ ] **[제가]** 사전 출시 보고서·크래시/ANR·저사양 QA

## 7단계 · 제출·심사
- [ ] **[회장님]** 프로덕션 제출 → 구글 심사
- [ ] (iOS) Apple Developer $99 + App Store Connect·스크린샷·심사

## 8단계 · 출시 후
- [ ] 크래시/리뷰 모니터링
- [ ] 광고(google_mobile_ads + UMP 동의)
- [ ] 인앱결제/프리미엄
- [ ] 자동 백업 주기(workmanager)
- [ ] 애플 iCloud 구현체

---
### 제가 계정 없이 바로 가능한 항목(다음 시작점)
개인정보처리방침 전문 · 데이터 삭제 안내 · signingConfig 틀 · AAB 파이프라인 ·
기술점검 · 스토어 문구 · 스크린샷 시안 · 데이터 보안 양식 초안.
**회장님 선행 권장**: 키스토어 생성 · 12명·14일 비공개 테스트(일정 최대 변수).

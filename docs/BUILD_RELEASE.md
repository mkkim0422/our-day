# 릴리스 빌드 가이드 (AAB) — 그날 우리

> Google Play 는 APK 가 아니라 **AAB(Android App Bundle)** 를 받습니다.
> 이 문서대로 하면 스토어 업로드용 `.aab` 가 나옵니다.

## 0. 사전 준비 (한 번만)

1. **릴리스 키스토어 생성** (회장님 — 비밀번호·파일 안전 보관):
   ```bash
   keytool -genkey -v -keystore android/our-day-release.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias our-day
   ```
   ⚠️ 이 `.jks` 를 잃어버리면 앱 업데이트가 영원히 불가합니다. 백업 2곳 이상.

2. **android/key.properties 작성**:
   `android/key.properties.template` 를 복사해 `android/key.properties` 로 저장하고
   비밀번호·alias 를 채웁니다. (이 파일과 `.jks` 는 `.gitignore` 로 커밋 차단됨.)

   > key.properties 가 **없으면** 빌드는 디버그 키로 폴백 서명합니다(스토어 업로드 불가,
   > 로컬 테스트용). 스토어 제출 전 반드시 정식 키를 등록하세요.

3. **릴리스 키 SHA-1 을 OAuth 클라이언트에 추가** (클라우드 백업용, 체크리스트 6번):
   ```bash
   keytool -list -v -keystore android/our-day-release.jks -alias our-day
   ```
   출력의 SHA-1 을 docs/CLOUD_BACKUP_SETUP.md 의 OAuth 클라이언트에 등록.
   (Play 앱 서명을 쓰면 콘솔이 발급하는 SHA-1 도 함께 등록해야 함 — 체크리스트 5번.)

## 1. 빌드

```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

산출물: `build/app/outputs/bundle/release/app-release.aab`

### 난독화 심볼까지 남기려면(크래시 역추적용, 권장)
```bash
flutter build appbundle --release \
  --obfuscate --split-debug-info=build/symbols
```
→ `build/symbols/` 폴더를 보관했다가, 크래시 스택 디버깅 시 사용.
(이 폴더는 `app.*.map.json`/symbols 로 .gitignore 처리되어 커밋되지 않음.)

## 2. 검증 (업로드 전)

```bash
# 버전 확인 (pubspec.yaml 의 version: 1.0.0+1 → versionName 1.0.0 / versionCode 1)
# 업데이트마다 +뒤 숫자(versionCode)를 올려야 함: 1.0.0+1 → 1.0.1+2 ...

# AAB 내용 점검 (선택, bundletool 필요)
# 서명 확인:
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
```

## 3. 업로드

Play Console → 테스트(내부/비공개) 또는 프로덕션 → 새 버전 만들기 →
`app-release.aab` 업로드 → 출시 노트 작성 → 검토 → 출시.

---

## 자주 나는 문제

| 증상 | 원인/해결 |
|---|---|
| `Keystore file ... not found` | key.properties 의 storeFile 경로 확인(android/ 기준 상대경로). |
| R8 후 런타임 크래시 | `android/app/proguard-rules.pro` 에 keep 규칙 추가(플러그인 클래스). |
| 업로드 시 "이미 사용된 versionCode" | pubspec 의 `+숫자`(versionCode) 를 올릴 것. |
| "디버그 키로 서명됨" 거부 | key.properties 미작성 → 정식 키 등록 후 재빌드. |
| 클라우드 백업 ApiException:10 | 릴리스 SHA-1 이 OAuth 에 미등록 → 0번 3단계. |

# 클라우드 백업 설정 체크리스트 (회장님 몫)

앱 안의 코드는 모두 구현돼 있습니다(로그인 → 드라이브 업로드/복원 → 용량 확인 →
꽉 차면 알림 + 로컬 백업 유도). **동작하려면 아래 "계정/키 설정"만** 해주시면 됩니다.
코드로는 만들 수 없는, 회장님 구글/애플 계정에 속한 부분입니다.

설정 전에도 앱은 정상 동작합니다. 단, 설정 화면에서 **[연결]**을 누르면
"개발자 오류(ApiException: 10)"가 뜹니다 — 아래 구글 설정을 끝내면 사라집니다.

---

## 핵심 값 (그대로 등록)

| 항목 | 값 |
|---|---|
| Android 패키지명 (applicationId) | `com.ourday.our_day` |
| 디버그/현재 릴리스 SHA-1 | `D3:00:7F:CD:66:AC:6F:57:7E:A5:CF:81:B8:9A:05:D6:89:8B:6F:B7` |
| 요청 스코프 | `https://www.googleapis.com/auth/drive.appdata` (앱 전용 숨김 폴더만) |

> ⚠️ 현재 릴리스 APK는 **디버그 키로 서명**됩니다(`android/app/build.gradle`의 TODO).
> 나중에 스토어 출시용 **정식 릴리스 키스토어**를 만들면, 그 키의 SHA-1도
> 같은 OAuth 클라이언트에 **추가**로 등록해야 합니다(아래 "릴리스 키 SHA-1" 참고).

---

## A. 구글 드라이브 (안드로이드·아이폰 공통, 1차)

1. **Google Cloud Console** 접속 → https://console.cloud.google.com
2. 상단에서 **프로젝트 새로 만들기**(예: `our-day`) 또는 기존 프로젝트 선택.
3. **API 및 서비스 → 라이브러리** → "Google Drive API" 검색 → **사용 설정**.
4. **API 및 서비스 → OAuth 동의 화면**
   - User Type: **외부(External)** 선택 → 만들기
   - 앱 이름: `그날 우리`, 사용자 지원 이메일: 회장님 이메일
   - 개발자 연락처 이메일 입력 → 저장
   - **범위(Scopes)**: `.../auth/drive.appdata` 추가 (민감 범위로 분류됨)
   - **테스트 사용자**: 백업에 쓸 **본인 구글 계정 이메일**을 추가
     (테스트 모드에서는 등록된 테스트 사용자만 로그인 가능 — 가족용이면 이걸로 충분)
5. **API 및 서비스 → 사용자 인증 정보 → 사용자 인증 정보 만들기 → OAuth 클라이언트 ID**
   - 애플리케이션 유형: **Android**
   - 패키지 이름: `com.ourday.our_day`
   - SHA-1 인증서 지문: `D3:00:7F:CD:66:AC:6F:57:7E:A5:CF:81:B8:9A:05:D6:89:8B:6F:B7`
   - 만들기 (별도 JSON 다운로드/코드 추가 **불필요** — google_sign_in이 패키지명+SHA-1로
     같은 프로젝트의 클라이언트를 자동 매칭합니다)
6. 끝. 앱 **설정 → 클라우드 백업 → [연결]** 눌러 본인 계정 로그인 →
   "지금 클라우드에 백업" 동작 확인.

### (선택) 공개 출시 시
- `drive.appdata`는 민감 범위라, 테스트 사용자 외 일반 사용자에게 열려면
  OAuth 동의 화면 **게시(Production)** + 구글 **앱 인증(verification)**이 필요할 수 있습니다.
  가족/지인 한정이면 테스트 사용자 등록만으로 OK.

### 릴리스 키 SHA-1 (정식 출시 키스토어를 만든 뒤)
```
# 키스토어 만든 후, 그 키의 SHA-1 확인:
keytool -list -v -keystore <릴리스.keystore> -alias <별칭>
```
나온 SHA-1을 5번의 OAuth 클라이언트에 **추가** 등록.
(또는 Play 앱 서명 사용 시, Play Console의 "앱 서명 키 인증서" SHA-1을 등록.)

---

## B. 애플 iCloud (아이폰, 추후 단계)

> 앱 코드는 구글 드라이브 추상화(`CloudBackupService`) 뒤에 있어, iCloud 구현체만
> 추가하면 화면 변경 없이 붙습니다. 다만 **시작 전 아래가 필요**합니다.

1. **Apple Developer Program 가입** (연 $99) — 이게 없으면 iCloud/Sign in with Apple
   자체가 불가합니다.
2. Apple Developer → Identifiers → App ID에 **iCloud** + **Sign in with Apple** capability 켜기.
3. iCloud Container 생성(예: `iCloud.com.ourday.ourday`).
4. Xcode에서 해당 capability 추가(Signing & Capabilities).
5. (그 후) iCloud Drive/CloudKit 연동 구현체를 추가 — 이 부분 코드는 제가 작성합니다.

---

## 현재 구현 범위 (앱 코드 — 완료)

- [x] `CloudBackupService` 추상화(구글/애플 공통 인터페이스)
- [x] 구글 드라이브 구현(로그인, appDataFolder에 .zip 업로드(청크/대용량), 목록,
      다운로드, 용량 조회, 삭제) — Drive REST 직접 호출
- [x] 설정 화면: 연결/해제, 용량 막대(90%↑ 경고), 지금 백업, 클라우드에서 복원
- [x] 용량 초과 시: 즉시 알림(`showBackupNeeded`) + 로컬 백업 유도 다이얼로그
- [x] 백업 본체는 로컬과 동일한 .zip 재사용(원본 화질, 누수 없는 manifest v2)

## 다음 단계 (앱 코드 — 추후)
- [ ] 자동 백업 주기(백그라운드) — workmanager 등, 배터리/정책 검토 후
- [ ] 애플 iCloud 구현체(위 B 설정 완료 후)

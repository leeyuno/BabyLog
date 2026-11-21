# App Store 출시 준비 (iOS)

App Store Connect에 입력할 값과 출시 전 확인 항목입니다.
스토어 문구는 `fastlane/metadata/ko/`에 있습니다. fastlane `deliver` 형식이라 나중에 자동 업로드에도 그대로 쓸 수 있습니다.

## 1. 출시 전에 직접 해야 할 것

| # | 할 일 | 어디서 |
|---|---|---|
| 1 | Apple Developer Program 가입 | developer.apple.com (연회비) |
| 2 | AdMob에 iOS 앱 등록 → **실제 앱 ID**를 `BabyLog/Info.plist`의 `GADApplicationIdentifier`에 넣기 | AdMob 콘솔 |
| 3 | `docs/_config.yml`의 닉네임·문의 이메일·시행일 채우기 → 푸시 → GitHub Pages 켜기 | GitHub 저장소 Settings > Pages (`main`, `/docs`) |
| 4 | Firebase 익명 로그인 켜기, Google Analytics 연결 | Firebase 콘솔 |
| 5 | App Store Connect에서 앱 만들기 (아래 2항) | App Store Connect > 앱 > + |
| 6 | Xcode에서 Product > Archive → Distribute App → App Store Connect | Xcode (`.xcworkspace`) |
| 7 | 위젯·잠금화면 스크린샷을 실제 기기에서 찍어 추가 (선택) | 아이폰 |

⚠️ 2번을 하지 않으면 **Archive가 실패하도록** 빌드 단계 "Release Checks"를 넣어 두었습니다. 테스트 광고 ID로 출시되는 것을 막기 위해서입니다. `GoogleService-Info.plist`가 없을 때도 실패합니다.

## 2. 앱 만들기

| 항목 | 값 |
|---|---|
| 플랫폼 | iOS |
| 이름 | `먹싸자 - 수유·기저귀·수면 기록` |
| 기본 언어 | 한국어 |
| 번들 ID | `com.leeyuno.babylog.ios` |
| SKU | `babylog-ios` (아무 값이나 가능, 바꿀 수 없음) |

## 3. 앱 정보

| 항목 | 값 |
|---|---|
| 부제 | `아기 안고 한 손으로 쓰는 육아 기록` |
| 카테고리 | 주: **건강 및 피트니스**, 보조: 라이프스타일 |
| 개인정보처리방침 URL | `https://leeyuno.github.io/BabyLog/privacy/` |
| 지원 URL | `https://leeyuno.github.io/BabyLog/` |
| 저작권 | `2026 <개발자 닉네임>` |
| 키즈 카테고리 | ⚠️ **선택하지 않습니다.** 부모용 앱이고, 키즈 카테고리는 제3자 광고·분석 SDK를 쓸 수 없습니다. |

## 4. 연령 등급 설문

- 모든 항목에 "없음"으로 답하되, **의료 또는 치료 정보**는 "드물게/경미하게"로 답합니다. 수유량 추천과 성장곡선이 있기 때문입니다.
- 광고가 있으므로 "광고 포함"이 있으면 "예"를 고릅니다.
- 등급은 설문 결과대로 받으면 됩니다.

## 5. 앱 개인정보 (개인정보 라벨)

"데이터 수집함"을 선택하고 아래처럼 답합니다. 내용은 `docs/privacy.md`, `BabyLog/PrivacyInfo.xcprivacy`와 일치해야 합니다.

| 데이터 유형 | 수집 주체 | 용도 | 사용자에게 연결 | 추적 |
|---|---|---|---|---|
| 건강 및 피트니스 > **건강** | 가족 공유를 켠 경우 (Firestore) | 앱 기능 | 예 | 아니요 |
| 식별자 > **사용자 ID** | 가족 공유 익명 계정 | 앱 기능 | 예 | 아니요 |
| 식별자 > **기기 ID** | AdMob, Firebase | 제3자 광고, 분석 | 아니요 | 아니요 ※ |
| 사용 데이터 > **제품 상호작용** | Analytics, AdMob | 분석, 제3자 광고 | 아니요 | 아니요 |
| 사용 데이터 > **광고 데이터** | AdMob | 제3자 광고 | 아니요 | 아니요 ※ |
| 진단 > **충돌 데이터** | Crashlytics | 앱 기능 | 아니요 | 아니요 |
| 진단 > **성능 데이터** | AdMob | 제3자 광고 | 아니요 | 아니요 |
| 진단 > **기타 진단 데이터** | Crashlytics, AdMob | 앱 기능, 분석 | 아니요 | 아니요 |
| 위치 > **대략적 위치** | AdMob (IP 기반) | 제3자 광고 | 아니요 | 아니요 |

※ 앱이 추적 허용(ATT) 팝업을 띄우지 않으므로 광고 식별자(IDFA)는 쓰이지 않고, "추적"은 아니요로 답합니다. 나중에 ATT를 넣어 맞춤 광고를 켜면 기기 ID·광고 데이터의 "추적"을 **예**로 바꾸고, `Info.plist`에 `NSUserTrackingUsageDescription`, 개인정보처리방침도 함께 고쳐야 합니다.

AdMob 항목은 Google 문서 "Prepare for Apple's App Store data disclosure requirements"(AdMob 도움말)와 대조해 확인하세요. SDK 버전마다 바뀔 수 있습니다.

## 6. 버전 정보

| 항목 | 값 |
|---|---|
| 버전 | 1.0 (빌드 1) — 다시 올릴 때는 빌드 번호(`CURRENT_PROJECT_VERSION`)를 올립니다 |
| 스크린샷 | `fastlane/screenshots/ko/` (6.9인치 1320×2868, `./scripts/screenshots.sh`로 다시 찍기) |
| 설명·키워드·홍보 문구 | `fastlane/metadata/ko/*.txt` |
| 심사 메모 | `fastlane/metadata/review_information/notes.txt` |
| 로그인 필요 | 아니요 (데모 계정 없음) |
| 수출 규정 | 암호화: 표준 HTTPS만 사용 → `ITSAppUsesNonExemptEncryption = NO`가 Info.plist에 있어 업로드할 때마다 묻지 않습니다 |

## 7. 빌드 설정 요약 (이미 반영됨)

- 최소 iOS 17.0으로 고정 (Xcode가 업데이트돼도 바뀌지 않음), 위젯은 16.2
- 아이폰 전용, 세로 화면 전용. 아이패드에서는 아이폰 호환 모드로 실행됩니다. 그래서 아이패드 스크린샷은 필요 없습니다.
- 앱 언어: 한국어(`developmentRegion = ko`). 날짜·시간과 시스템 버튼이 한국어로 나옵니다.
- 앱 아이콘 1024px, 투명 영역 없음
- 개인정보 매니페스트: 앱·위젯 각각 `PrivacyInfo.xcprivacy`
- Release에서만 Crashlytics dSYM 업로드

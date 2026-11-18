# CLAUDE.md — BabyLog

수유 · 기저귀 · 수면을 기록하는 iOS 육아 기록 앱입니다. SwiftUI와 Core Data로 만들었고, WidgetKit 위젯과 AdMob 광고가 붙어 있습니다.
UI 문자열과 코드 주석은 **한국어**로 씁니다.

## 빌드 / 실행

- Xcode 27.2와 CocoaPods 1.17.0(Homebrew)에서 검증했습니다.
- **최초 설정은 `./scripts/setup.sh` 한 번이면 됩니다.** 이 스크립트가 `pod install`을 실행해 `BabyLog.xcworkspace`를 만듭니다. 이후에는 **반드시 `.xcworkspace`로 엽니다.**
  - 의존성은 `Google-Mobile-Ads-SDK 11.5.0`(앱 타깃만)입니다. 버전은 `Podfile`과 `Podfile.lock`에 고정되어 있습니다.
  - `Pods/`는 gitignore 대상이고, `Podfile`, `Podfile.lock`, `BabyLog.xcworkspace`는 커밋합니다.
  - 위젯 익스텐션에는 광고 SDK를 넣지 않습니다.
  - Podfile의 타깃 구조(`BabyLogTests`는 `inherit! :search_paths`, UITests는 앱 상속)는 pbxproj의 Pods 설정과 맞아야 합니다.
- `xcode-select`가 Command Line Tools를 가리키는 머신에서는 `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`를 먼저 설정합니다. 스크립트는 이 처리를 자동으로 합니다.
- 빌드 검증 명령:
  ```sh
  xcodebuild -workspace BabyLog.xcworkspace -scheme BabyLog -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO build
  ```
- 단위 테스트는 `./scripts/test.sh`로 실행합니다(시뮬레이터 지정은 `SIM="..."`).
  - ⚠️ 테스트에 `CODE_SIGNING_ALLOWED=NO`를 쓰면 안 됩니다. App Group 엔타이틀먼트가 빠져서 호스트 앱이 시작하자마자 크래시합니다.
  - 스크립트는 로컬 ad-hoc 서명(`CODE_SIGN_IDENTITY=-`)을 사용합니다.
- 스킴: `BabyLog`(앱과 단위 테스트), `BabyLogWidgetExtension`(위젯)
- 배포 타깃: 앱과 단위 테스트는 `$(RECOMMENDED_IPHONEOS_DEPLOYMENT_TARGET)`(Xcode 27 기준 17.0), 위젯과 UI 테스트는 16.2(프로젝트 기본값), Pods는 16.0(Podfile의 post_install에서 설정)
  - ⚠️ 테스트 타깃이 앱보다 낮으면 `@testable import` 단계에서 컴파일 에러가 납니다. 배포 타깃을 바꿀 때는 모든 타깃을 함께 맞춥니다.

## 디렉터리 구조

```
BabyLog/                 앱 타깃
  BabyLogApp.swift       진입점: Core Data/Router 주입, 딥링크
  Persistence.swift      앱 Core Data 스택 + context.saveAndRefreshWidgets()
  Model/                 엔티티, enum, 라우팅, 집계, 수유 가이드, 광고 설정
  Presentation/          SwiftUI 화면/컴포넌트 (일부는 위젯에서도 쓰임)
BabyLogWidget/           위젯 익스텐션 (수유 경과 / 오늘 통계 / 오늘 vs 6일 평균 / 빠른 추가)
BabyLogTests/            단위 테스트 (Router, CareStats, DailySummary, LastValueProvider, FeedingGuide)
```

## 타깃 멤버십 ⚠️ 가장 자주 깨지는 부분

**앱과 위젯 두 타깃에 모두 포함되는 파일**: `DailySummary.swift`, `CareEvent.swift`, `BabyLog.swift`(Baby), `WeightRecord.swift`, `FeedSchedule.swift`, `CoreEnums.swift`, `Routing.swift`,
`AddQuickHomeWidgetView.swift`, `AddQuickLockWidgetView.swift`, `DailySummaryWidgetChipView.swift`, `BabyLog.xcdatamodeld`, `BabyLogWidget.intentdefinition`,
그리고 **위젯 파일 4개**(`BabyLogElapsedWidget`, `BabyLogTodayWidget`, `BabyLogDailySummaryWidget`, `BabyLogQuickAddWIdget`)입니다. 이 4개는 앱 타깃에서도 컴파일됩니다.

**위젯 타깃에만 들어가는 파일**: `BabyLogWidgetBundle.swift`(@main), `BabyLogWidgetLiveActivity.swift`
**앱 타깃에만 들어가는 파일**: 위 목록에 없는 나머지 전부입니다(예: `FeedingGuide.swift`, `WHOGrowth.swift`, `FeedReminder.swift`, `BabyPhotoStore.swift`, `GrowthView.swift`, `SettingsView.swift`, `Persistence.swift`, 광고 관련 파일).

- 위 파일에서는 `UIKit`, `GoogleMobileAds`, `PersistenceController`, `WidgetCenter`, `FeedingGuide`처럼 **앱 전용 심볼을 참조하면 안 됩니다.**
  반대로 위젯 파일이 쓰는 헬퍼(예: `.widgetBackground()`)는 양쪽 타깃에 포함된 파일에 둬야 합니다. 위젯 전용 파일에 두면 앱 빌드가 깨집니다.
  가용성 분기는 `#available(iOS 17.0, *)`로 씁니다. `iOSApplicationExtension`으로 쓰면 앱 타깃에서 분기가 의도대로 동작하지 않습니다.
- 새 파일을 추가하면 어느 타깃에 넣을지 꼭 정해야 합니다. 이 작업 환경에는 Xcode가 없을 수 있습니다. 그럴 때는 `project.pbxproj`를 직접 편집하고 `plutil -lint`로 검증합니다.
  편집할 곳은 PBXBuildFile, PBXFileReference, 그룹, 그리고 해당 타깃의 PBXSourcesBuildPhase입니다.
- App Group 엔타이틀먼트는 두 타깃 모두에 있어야 합니다. `BabyLog/BabyLog.entitlements`, `BabyLogWidget/BabyLogWidget.entitlements`에 `group.com.leeyuno.babylog.ios`가 들어갑니다.

## 데이터 계층 (Core Data, Codegen = Manual)

- 엔티티: `Baby`(id, name, birthday, weightKg[0=미입력], manualAgeMonths[-1=미입력], events·weightRecords는 Cascade), `CareEvent`(kindRaw, feedTypeRaw, feedAmountML, diaperTypeRaw, sleepStartAt/EndAt, note, createdAt, baby), `WeightRecord`(id, measuredAt[그 날 자정], weightKg, baby)
- 스토어는 App Group 컨테이너의 `BabyLog.sqlite`(`BabyLogGroup.storeURL`)입니다. 앱과 위젯이 같은 파일을 읽습니다.
- 모델은 `CoreDataModel.shared` 하나만 씁니다. 컨테이너를 만들 때는 반드시 `NSPersistentContainer(name:managedObjectModel: CoreDataModel.shared)`를 사용합니다.
- enum의 rawValue(Int16)는 DB에 그대로 저장됩니다. **기존 값을 바꾸거나 번호를 다시 매기면 안 되고, 새 값은 추가만 합니다.** 값이 없으면 `Int16.min` 센티널을 씁니다(`feedType = nil`).
- **모델 버전**: 현재 버전은 `BabyLog 3.xcdatamodel`입니다(`.xccurrentversion`). v2는 몸무게·개월수, v3는 `WeightRecord`, v4는 `Baby.sexRaw`와 `CareEvent.breastLeftSec`/`breastRightSec`/`breastLastSide`를 추가했습니다. 출시된 버전을 직접 고치면 기존 스토어를 열지 못해 크래시가 납니다.
  스키마를 바꿀 때는 **새 버전을 추가**합니다. 순서는 다음과 같습니다.
  1. 폴더 복사
  2. `.xccurrentversion` 수정
  3. pbxproj의 XCVersionGroup에서 children과 currentVersion 수정
  4. `CareEvent.swift`/`BabyLog.swift` 수정

  경량 마이그레이션이 가능한 변경(옵셔널이거나 기본값이 있는 속성 추가)만 하고, 자동 마이그레이션은 기본으로 켜져 있습니다.
- **`createdAt` 규칙**: 타임라인 정렬과 일별 집계의 기준이 되는 값입니다. 수면은 종료 시각, 진행 중이면 시작 시각을 넣습니다(AddEventView의 추가와 편집이 같은 규칙).
- 저장은 `try context.saveAndRefreshWidgets()`로 합니다. 실패하면 롤백한 뒤 에러를 다시 던지고, 성공하면 위젯을 즉시 새로고침합니다. `try? context.save()`는 쓰지 않습니다.
- 현재 UI는 **첫 번째 아기(이름순) 한 명만** 다룹니다. 위젯은 `SharedPersistence.firstBaby`를 씁니다.

## 집계 규칙 (단일 소스: `CareStats` / `DailySummary` in DailySummary.swift)

- 일별 집계는 `createdAt`이 속한 날짜(startOfDay)를 기준으로 합니다.
  - 수유는 ml 합계입니다.
  - 배변은 `poop` + `mixed` 횟수이고, 소변만 있는 기록은 세지 않습니다.
  - 수면은 종료된 기록만 넣고 진행 중인 수면은 빼며, 분 단위로 계산합니다.
- "오늘 vs 6일 평균"에서 평균은 오늘을 뺀 앞 6일로 냅니다(기록이 없는 날은 0으로 포함).
- 주간 개요 화면과 위젯이 같은 함수를 씁니다. 집계 규칙을 바꾸면 양쪽에 반영되므로 `BabyLogTests`도 함께 고칩니다.
- 예외: `BabyLogTodayWidget`은 수면을 "오늘 구간과 겹치는 분"으로 계산합니다(자정 경계 처리).

## 수유량 자동 추천 (`FeedingGuide.swift`, `SettingsView.swift`)

- 설정 탭에서 아기 정보(이름, 생일 또는 직접 입력한 개월수, 몸무게)를 수정하고, `수유량 자동 추천` 스위치를 켜고 끕니다. 스위치 값은 `@AppStorage(FeedingSettings.autoRecommendKey)`에 저장되고 기본값은 OFF입니다.
- 1회 권장량은 `min(체중×150, 1000) ÷ 하루 수유 횟수`를 10ml 단위로 반올림하고 10~300ml로 보정한 값입니다.
  하루 수유 횟수는 0개월 8회, 1개월 7회, 2~3개월 6회, 4~5개월 5회, 6개월 이상 4회입니다.
- AddEventView의 기본값은 `FeedingGuide.defaultFeedAmount`가 결정합니다.
  - 자동 추천이 꺼져 있으면 직전 수유량을 씁니다.
  - 켜져 있고 최근 5회 평균이 권장량보다 적으면 권장량을 씁니다.
  - 켜져 있지만 평균이 권장량 이상이면 직전 수유량을 씁니다.
  - 기록이 하나도 없으면 권장량을 씁니다.
  - 체중이나 개월수가 입력되지 않았으면 꺼져 있을 때와 같습니다.
- 권장량은 의료 정보이므로 UI에 **"참고용"이라는 안내와 전문의 상담 안내를 반드시 함께 표시**합니다. 공식이나 표를 바꾸면 `BabyLogTests`의 FeedingGuide 테스트도 함께 고칩니다.

## 프로필 사진 / 성장 기록

- **사진**(`BabyPhotoStore`): Core Data가 아니라 파일로 저장합니다.
  - 위치는 App Group 컨테이너의 `BabyPhotos/<babyId>.jpg`입니다.
  - 저장할 때 가운데를 정사각형으로 잘라 600px JPEG로 줄입니다.
  - 화면은 `BabyAvatarView`를 씁니다. 스토어를 구독하므로 사진을 바꾸면 모든 화면에 바로 반영됩니다.
- **몸무게 기록**(`WeightRecord`, `GrowthStore`)
  - 기록은 **하루에 한 건**입니다. 같은 날짜로 다시 입력하면 그 날 기록을 갱신합니다.
  - `Baby.weightKg`는 항상 **가장 최근 날짜 기록과 같게 유지**합니다(`syncLatestWeight`). 그래서 수유량 자동 추천이 자동으로 갱신됩니다.
  - 설정에서 몸무게를 바꿔 저장하면 오늘 날짜 기록이 생깁니다.
  - 성장 기록 도입 전에 입력한 몸무게는 성장 탭을 처음 열 때 첫 기록으로 옮깁니다(`seedIfNeeded`).
- **성장 탭**(`GrowthView`): 차트의 x축은 생일 기준 개월수(`GrowthMath.ageMonths`, 일수 ÷ 30.4375)입니다. 생일이 없으면 날짜 축으로 그립니다.
- **WHO 성장곡선**(`WHOGrowth`, `GrowthChartView`)
  - 성별과 생일이 있고 기록이 24개월 이하일 때만 표시합니다. 연령별 체중 0~24개월 L·M·S 표를 쓰고, 개월 사이 값은 선형 보간합니다.
  - 표는 CDC가 배포한 WHO CSV에서 옮긴 값이라 **손으로 고치지 않습니다**. 테스트가 CSV의 5·95 백분위 값과 대조합니다.
  - 화면에는 3~97 / 15~85 백분위 음영, 중앙값 점선, 최신 기록의 백분위를 그리고, "진단이 아닌 참고용" 문구를 반드시 함께 표시합니다.
- 다음 단계 후보: 키·머리둘레 기록(같은 구조와 WHO 표로 확장 가능).

## 모유 직접 수유 / 다음 수유 예상

- **모유 직접 수유**(`BreastTimer`, `BreastTimerView`)
  - 모유를 고르면 `[직접 수유 | 젖병]`을 선택합니다. 직접 수유는 왼쪽·오른쪽 타이머로 초를 기록하고 ml은 0으로 둡니다.
  - **직접 수유 판별은 "모유이면서 ml이 0"** 입니다(`isDirectBreastfeeding`). 따로 플래그를 두지 않습니다.
  - 타이머는 시작 시각을 기준으로 계산하므로 화면이 꺼져도 정확합니다. 단 앱이 종료되면 사라지고, 진행 중에 닫으려 하면 확인을 받습니다.
  - 기록 시각은 사용자가 시간을 고르지 않았으면 **타이머를 처음 시작한 시각**입니다.
  - `lastFeedingML`은 ml이 0보다 큰 기록만 봅니다. 직수 기록 때문에 기본값이 60ml로 돌아가지 않게 하기 위해서입니다. 다음 수유 때는 지난번 마지막 쪽의 반대쪽을 안내합니다.
- **다음 수유 예상**(`FeedSchedule`, 위젯과 공용)
  - 최근 48시간 수유를 쓰고, 30분 이내에 이어진 수유는 한 번으로 묶습니다. 간격은 최근 8개 간격의 **중앙값**이고, 3회 미만이면 예측하지 않습니다.
  - 타임라인 상단 카드와 수유 경과 위젯에 표시합니다.
- **알림**(`FeedReminder`)
  - 설정에서 켠 경우에만 예상 시각(또는 10·20분 전)에 로컬 알림을 **1건만** 예약합니다.
  - 기록을 저장할 때(`saveAndRefreshWidgets`), 앱이 활성화될 때, 설정을 바꿀 때 다시 예약합니다.

## 딥링크

- `babylog://add?type=sleep|feeding|diaper`를 받으면 `Router.route = .add(kind)`가 되고, `RootView`가 `AddEventView` 시트를 띄웁니다. 시트가 닫히면 `router.reset()`이 호출됩니다.
- URL은 반드시 `DeepLink.add(_:)`로 만듭니다. 문자열을 직접 조립하지 않습니다.
- `AddKind.rawValue`는 이미 설치된 위젯이 들고 있는 링크 값이므로 바꾸면 안 됩니다. 예전 값 `type=feed`는 `.feeding` 별칭으로 계속 받습니다.
- `AddKind.feeding`과 `CareKind.feed`는 이름이 다르니 주의합니다. 변환은 `CareKind(from:)`와 `AddKind(from:)`로 합니다.

## 위젯 (BabyLogWidget)

- 데이터는 `SharedPersistence.read { ctx in ... }`로 읽습니다. 매번 새 백그라운드 컨텍스트를 쓰고, 스토어에 접근할 수 없으면 nil을 돌려주므로 강제 언래핑하지 않습니다.
- 모든 엔트리 뷰에 `.widgetBackground()`를 붙입니다. iOS 17+에서는 containerBackground가 필수입니다.
- 위젯의 `kind` 문자열은 바꾸면 안 됩니다. 사용자가 홈 화면에 둔 위젯이 사라집니다.
- 경과 시간은 `Text(date, style: .timer)`로 표시합니다. 분 단위 타임라인 갱신은 하지 않습니다(갱신 예산 절약).
- `BabyLogWidgetLiveActivity.swift`는 템플릿 그대로이고 번들에 등록되어 있지 않습니다.

## 광고 (AdMob)

- `AdsConfig`: DEBUG 빌드는 구글 테스트 유닛, RELEASE 빌드는 실제 유닛을 씁니다. 테스트 중에 실제 유닛 ID를 쓰지 않습니다.
- ⚠️ `Info.plist`의 `GADApplicationIdentifier`는 아직 **테스트 앱 ID**입니다. 출시 전에 실제 앱 ID로 바꿔야 합니다.
- **화면을 가리는 전면 광고(앱 오프닝, 인터스티셜)는 쓰지 않습니다.**
  - 앱을 여는 순간은 대부분 "지금 바로 기록해야 하는" 순간입니다. 이때 화면을 가리면 제품 컨셉(빠른 기록)과 정면으로 충돌합니다.
  - 2026-11 결정으로 앱 오프닝 광고(`AppOpenAdManager`)를 제거했습니다. 수익이 높아도 다시 넣지 않습니다.
- 현재 광고는 타임라인 하단 배너(`BannerView`) 하나입니다. 앱 톤에 맞는 네이티브 광고 카드로 바꾸는 것을 검토 중입니다.
- 광고를 새로 추가할 때는 **기록 동선(타임라인 → 입력 시트 → 저장)을 막지 않는 위치와 형식**이어야 합니다.

## UX 원칙 (제품 컨셉)

부모가 **아이를 안고 한 손으로, 졸린 상태에서** 쓰는 앱입니다. 입력이 조금이라도 불편하면 사용자는 기록을 그만둡니다. 기능을 추가하거나 바꿀 때 다음을 지킵니다.

- **탭 수를 최소화합니다.** 종류나 타입 같은 선택지는 segmented, 자주 쓰는 값은 칩 한 번으로 고를 수 있게 합니다. 세밀한 입력(피커, 키보드)은 보조 수단으로만 씁니다.
- **기본값을 똑똑하게 정합니다.**
  - 시간의 기본값은 "지금"입니다. 사용자가 손대지 않으면 시트를 연 시각이 아니라 저장한 시각으로 기록합니다.
  - 수유량은 직전 값이나 권장량으로 미리 채웁니다.
- **모든 기록은 나중에 고칠 수 있어야 합니다.** 타임라인에서 행을 탭하면 `AddEventView(editing:)`가 열리고, 종류, 양, 시간, 메모를 모두 수정하거나 삭제할 수 있습니다.
- **기록 동선을 광고로 막지 않습니다.** 전면 광고는 쓰지 않습니다(광고 섹션 참고).
- **실수를 방지합니다.** 풀 스와이프 삭제는 막고, 시트 안에서 삭제할 때는 한 번 더 확인을 받습니다. 미래 시각은 입력할 수 없습니다.
- 기록 추가와 편집은 **한 화면(`AddEventView`)** 에서 처리합니다. 편집 전용 화면을 따로 만들지 않습니다.

## 코드 컨벤션

- 파일 헤더 아래에 그 파일의 역할을 한국어 1~3줄로 적습니다. 비직관적인 규칙은 `⚠️`로 표시합니다.
- 디버그용 `print`는 남기지 않습니다. 에러 로그만 허용합니다.
- iOS 16 호환을 유지합니다. iOS 17 전용 API는 `#available`로 분기합니다.
- 새 화면에는 `PreviewPersistence.controller`를 쓰는 `PreviewProvider`를 붙입니다.
- 커밋 메시지는 `[feat] 한글 설명`, `[fix] 한글 설명` 형식입니다.

### 서식 규칙 (SwiftLint 기본 룰 기준)

새로 쓰거나 고치는 코드는 아래 규칙을 지킵니다. 기존 코드도 손대는 김에 맞춥니다.

- 검사: 저장소 루트에서 `swiftlint`를 실행합니다(설정은 `.swiftlint.yml`). 커밋 전에 위반 0을 유지합니다.
- `xcode-select`가 Command Line Tools를 가리키면 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`를 앞에 붙입니다.
- 짧은 지역 변수 이름(`e`, `ml`)과 여러 줄 인자의 끝 쉼표는 허용합니다. TODO 주석은 "알려진 이슈"와 함께 관리하므로 검사하지 않습니다.

| 항목 | 기준 | 대응 SwiftLint 룰 |
|---|---|---|
| 한 줄 길이 | **120자 이하**. 주석과 문자열도 포함합니다 | `line_length` |
| 함수 본문 | 50줄 이하. 길어지면 private 함수나 하위 View로 나눕니다 | `function_body_length` |
| 타입 본문 | 300줄 이하. View가 길면 `@ViewBuilder private var`나 별도 `struct`로 나눕니다 | `type_body_length` |
| 파일 길이 | 500줄 이하 | `file_length` |
| 매개변수 | 5개 이하. 넘으면 입력 구조체로 묶습니다 | `function_parameter_count` |
| 중첩 | `if`/`for` 중첩은 3단계 이하. `guard`로 일찍 빠져나갑니다 | `cyclomatic_complexity`, `nesting` |
| 강제 처리 | `!` 강제 언래핑, `try!`, `as!` 금지. `guard let`, `do-catch`, `as?`를 씁니다 | `force_unwrapping`, `force_try`, `force_cast` |
| 들여쓰기 | 공백 4칸, 줄 끝 공백 없음, 파일 끝 빈 줄 1개 | `trailing_whitespace`, `trailing_newline` |
| 한 줄 한 문장 | `;`로 여러 문장을 한 줄에 쓰지 않습니다 | `trailing_semicolon` |
| 쉼표·콜론 | `a, b` / `name: Type` / `[Key: Value]` | `comma`, `colon` |
| 클로저 | 인자가 여러 줄에 걸치면 `$0` 대신 이름을 붙입니다 | `shorthand_argument` |

### 긴 줄 나누는 법

인자가 많거나 120자를 넘으면 **인자 하나당 한 줄**로 쓰고, 닫는 괄호는 따로 한 줄에 둡니다.

```swift
// ❌
let request = CareEvent.fetchRequest(for: baby, kind: .feed, from: startOfDay, to: endOfDay, limit: 5)

// ✅
let request = CareEvent.fetchRequest(
    for: baby,
    kind: .feed,
    from: startOfDay,
    to: endOfDay,
    limit: 5
)
```

- SwiftUI modifier 체인은 **modifier 하나당 한 줄**로 씁니다. 짧은 modifier는 두 개까지만 한 줄에 둡니다.
- 조건이 길면 `guard`/`if` 조건을 쉼표 단위로 나누거나, 의미 있는 이름의 지역 상수로 먼저 뺍니다.
- 긴 문자열은 `+`로 잇지 말고 여러 줄 문자열(`"""`)이나 지역 상수로 나눕니다.
- 긴 주석은 여러 줄의 `///` 또는 `//`로 나눕니다.
- 함수 선언이 120자를 넘으면 매개변수를 한 줄에 하나씩 쓰고, `)` 뒤에 반환 타입을 붙입니다.

## 알려진 이슈 / TODO

- 앱의 배포 타깃이 `$(RECOMMENDED_IPHONEOS_DEPLOYMENT_TARGET)`이라서 **Xcode를 업데이트하면 최소 지원 iOS 버전이 저절로 올라갈 수 있습니다.** 출시 전에 명시적인 버전(예: 17.0)으로 고정하는 것을 권장합니다.
- `PersistenceController`는 스토어 로드에 실패하면 `fatalError`를 냅니다. 사용자에게 알리고 복구하는 경로가 필요합니다.
- `TimelineView`(24시간)와 `WeeklyOverviewView`(7일)의 기준 시각은 init 시점에 고정됩니다. 자정을 넘겨 앱을 켜 두면 범위가 갱신되지 않습니다.
- `ChartsGroupedBars`는 단위가 다른 세 지표를 한 y축에 그립니다. 수유 값이 너무 커서 수면과 배변 막대가 묻힙니다.
- `MetricChipView`와 `DailySummaryWidgetChipView`의 로직이 중복됩니다(폰트만 다름). 고칠 때는 둘 다 고쳐야 합니다.
- `FallbackBars.swift`는 쓰이지 않으므로 삭제 후보입니다.
- 아기를 여러 명 다루는 기능은 아직 없습니다. 아기 정보와 사진 수정은 설정 탭에서 할 수 있습니다.
- 온보딩에서는 몸무게를 입력받지 않습니다. 자동 추천을 쓰려면 설정 탭에서 따로 입력해야 합니다.

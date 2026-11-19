# BabyLog 👶

아이를 안고 한 손으로도 쓸 수 있도록 만든 **수유 · 기저귀 · 수면 기록 iOS 앱**입니다.

> 입력이 조금이라도 불편하면 결국 기록을 그만두게 됩니다.
> 그래서 BabyLog는 "탭 몇 번이면 끝나는 기록"을 가장 중요하게 생각합니다.

## 주요 기능

### 빠른 기록
- 수유(분유/모유, ml), 기저귀(소변/대변/혼합), 수면(시작/종료, 자는 중)을 기록합니다.
- 시간의 기본값은 **지금**입니다. `5분 전 / 15분 전 / 30분 전 / 1시간 전` 칩을 한 번 탭해서 고를 수도 있습니다.
- 수유량은 **직전 값으로 미리 채워집니다.**
- 홈 화면이나 잠금화면 위젯에서 바로 기록 화면을 열 수 있습니다(`babylog://add?type=feeding`).

### 언제든 수정
- 타임라인에서 기록을 탭하면 종류, 수유량, 시간, 메모를 모두 고칠 수 있습니다.
- 스와이프로 편집하거나 삭제할 수 있습니다. 실수로 지우지 않도록 끝까지 밀어서 바로 삭제하는 기능은 막아 두었습니다.

### 프로필 · 성장 기록 (성장 탭)
- 설정에서 아기 사진을 고르면 타임라인과 성장 탭에 프로필로 표시됩니다.
- 몸무게를 기록하면 **개월수별 성장 그래프**와 직전 기록 대비 증감을 보여줍니다.
- 몸무게는 하루에 한 건이고, 최신 몸무게가 수유량 자동 추천에 바로 반영됩니다.
- 성별을 입력하면 **WHO 성장곡선**(0~24개월)과 비교하고 백분위를 보여줍니다(참고용).

### 모유 수유 · 다음 수유 예상
- 모유 **직접 수유**는 ml 대신 왼쪽/오른쪽 타이머로 기록하고, 다음엔 반대쪽부터 먹이도록 안내합니다.
- 최근 수유 간격으로 **다음 수유 시각**을 예상해 타임라인과 위젯에 보여줍니다. 설정에서 알림을 켤 수도 있습니다.

### 원탭 기록 · 밤 모드 · 백업
- **원탭 기록 위젯**(iOS 17+): 홈 화면에서 `소변 / 대변 / 분유(직전 양) / 잠들었어요·깼어요`를 앱을 열지 않고 바로 저장합니다.
- **밤 모드**: 22시~6시에는 어둡고 따뜻한 화면에 큰 글씨로 바뀝니다. 새벽 수유 때 아이가 깨지 않게 합니다.
- **백업/복원**: 기록과 사진을 파일 하나로 내보내고 불러옵니다. 안드로이드 앱과 형식이 같아서 기기 사이 이전도 됩니다.

### 수유량 자동 추천 (설정 탭)
- 몸무게와 개월수를 입력하고 **자동 추천**을 켜면 1회 권장 수유량을 계산합니다.
  - 1일 총량은 체중(kg) × 150 ml이고, 최대 1,000 ml입니다.
  - 1회 권장량은 1일 총량을 개월수별 하루 수유 횟수(0개월 8회 ~ 6개월 이상 4회)로 나눈 값입니다.
- 최근 평균 수유량이 권장량보다 적으면 새 기록의 기본값이 권장량으로 바뀝니다.
- ⚠️ 권장량은 일반적인 공식으로 계산한 **참고값**입니다. 아기마다 다를 수 있으니 정확한 수유량은 소아청소년과 전문의와 상담하세요.

### 통계
- **타임라인:** 최근 24시간 기록을 보여줍니다.
- **주간 개요:** 최근 7일 합계, 날짜별 차트, "오늘 vs 직전 6일 평균"을 보여줍니다.

### 위젯
| 위젯 | 크기 | 내용 |
|---|---|---|
| 수유 경과 시간 | 소형, 잠금화면 | 마지막 수유 이후 경과 시간(실시간) |
| 오늘 통계 | 중형, 잠금화면 | 오늘 수유 횟수와 총량, 수면, 배변 |
| 오늘 vs 6일 평균 | 중형 | 수면, 수유, 배변을 평균과 비교 |
| 빠른 기록 추가 | 소형, 중형, 잠금화면 | 탭하면 기록 화면을 엶 |

## 기술 스택

- SwiftUI, Core Data(App Group으로 위젯과 공유), WidgetKit, Swift Charts
- Google Mobile Ads(AdMob) 11.5.0, CocoaPods로 관리. 화면을 가리는 전면 광고는 쓰지 않음
- 단위 테스트는 XCTest, 서식 검사는 SwiftLint

## 시작하기

### 요구 사항
- macOS와 Xcode(Xcode 27.2에서 검증)
- [CocoaPods](https://cocoapods.org): `brew install cocoapods`

### 설치
```sh
git clone https://github.com/leeyuno/BabyLog.git
cd BabyLog
./scripts/setup.sh          # pod install → BabyLog.xcworkspace 생성
open BabyLog.xcworkspace    # ⚠️ .xcodeproj 가 아닌 workspace 로 열어야 합니다
```

> `.xcodeproj`로 열면 `Framework 'Pods_…' not found` 링크 에러가 납니다.

### 테스트 · 린트
```sh
./scripts/test.sh                 # 시뮬레이터 단위 테스트 (SIM="iPhone 17 Pro" 로 기기 지정)
swiftlint                         # 서식 검사 (.swiftlint.yml)
```

> `xcode-select`가 Command Line Tools를 가리키는 환경이라면 아래 둘 중 하나를 먼저 실행하세요.
> - `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`
> - `sudo xcode-select -s /Applications/Xcode.app`

## 프로젝트 구조

```
BabyLog/                 앱
  BabyLogApp.swift       진입점 (Core Data · 딥링크)
  Persistence.swift      Core Data 스택 (App Group 공유 스토어)
  Model/                 엔티티, 집계(CareStats), 수유 가이드(FeedingGuide), 라우팅, 광고
  Presentation/          SwiftUI 화면 (타임라인, 주간 개요, 성장, 설정, 기록 입력/편집)
BabyLogWidget/           위젯 익스텐션
BabyLogTests/            단위 테스트
scripts/                 setup.sh, test.sh
CLAUDE.md                개발 가이드 (아키텍처, 데이터 규칙, UX 원칙, 알려진 이슈)
```

자세한 설계 규칙은 [CLAUDE.md](CLAUDE.md)에 정리되어 있습니다. 앱과 위젯의 타깃 구성, Core Data 마이그레이션, 집계 기준, 광고 정책 등을 다룹니다.

## 출시 전 체크리스트

- [ ] `Info.plist`의 `GADApplicationIdentifier`를 실제 AdMob 앱 ID로 교체(현재는 테스트 ID)
- [ ] 앱 배포 타깃을 명시적인 iOS 버전으로 고정(현재는 `$(RECOMMENDED_IPHONEOS_DEPLOYMENT_TARGET)`)
- [ ] 실기기에서 App Group 서명 확인(앱과 위젯 모두 `group.com.leeyuno.babylog.ios`)

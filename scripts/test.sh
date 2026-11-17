#!/usr/bin/env bash
# 단위 테스트 실행 (시뮬레이터)
#
#   ./scripts/test.sh                       # 기본 시뮬레이터
#   SIM="iPhone 17 Pro" ./scripts/test.sh   # 시뮬레이터 지정
#   ./scripts/test.sh IPHONEOS_DEPLOYMENT_TARGET=17.0   # 추가 빌드 설정 전달
#
# ⚠️ CODE_SIGNING_ALLOWED=NO 로 돌리면 App Group 엔타이틀먼트가 빠져 호스트 앱이 시작 시 크래시한다
#    (PersistenceController 가 App Group 컨테이너를 요구). 그래서 로컬 ad-hoc 서명(-)을 사용한다.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -z "${DEVELOPER_DIR:-}" && "$(xcode-select -p)" == *CommandLineTools* ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
export PATH="$DEVELOPER_DIR/usr/bin:$PATH"   # xcodebuild 가 simctl 을 찾을 수 있도록

[[ -d BabyLog.xcworkspace && -d Pods ]] || ./scripts/setup.sh

SIM="${SIM:-iPhone 17}"
xcodebuild -workspace BabyLog.xcworkspace -scheme BabyLog \
  -destination "platform=iOS Simulator,name=$SIM" \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
  -only-testing:BabyLogTests "$@" test

#!/usr/bin/env bash
# BabyLog 개발 환경 설정: CocoaPods 의존성 설치 → BabyLog.xcworkspace 생성
#
#   ./scripts/setup.sh            # pod install (Podfile.lock 버전 그대로)
#   ./scripts/setup.sh --repo     # 스펙 저장소 갱신 후 설치 (새 Pod 버전을 못 찾을 때)
set -euo pipefail
cd "$(dirname "$0")/.."

# 1) Xcode: xcode-select 가 Command Line Tools 를 가리키면 Xcode.app 을 임시 지정 (sudo 불필요)
if [[ -z "${DEVELOPER_DIR:-}" && "$(xcode-select -p)" == *CommandLineTools* ]]; then
  if [[ -d /Applications/Xcode.app ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
    echo "ℹ️  DEVELOPER_DIR=$DEVELOPER_DIR 사용 (영구 설정: sudo xcode-select -s /Applications/Xcode.app)"
  else
    echo "❌ Xcode.app 이 없습니다. App Store 에서 Xcode 를 설치하세요." >&2; exit 1
  fi
fi

# 2) CocoaPods
if ! command -v pod >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "📦 CocoaPods 설치 (Homebrew)"; brew install cocoapods
  else
    echo "❌ CocoaPods 가 없습니다. 'brew install cocoapods' 또는 'sudo gem install cocoapods' 후 다시 실행하세요." >&2; exit 1
  fi
fi
echo "ℹ️  CocoaPods $(pod --version)"

# 3) 설치 — Podfile.lock 에 고정된 버전으로
if [[ "${1:-}" == "--repo" ]]; then
  pod install --repo-update
else
  pod install
fi

echo "✅ 완료: open BabyLog.xcworkspace  (.xcodeproj 로 열지 말 것)"

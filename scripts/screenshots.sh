#!/bin/sh
# 앱스토어 스크린샷 자동 촬영 (6.9인치 iPhone 17 Pro Max, 1320×2868).
#   DEBUG 빌드를 데모 모드(-screenshotDemo: 인메모리 데모 기록, 광고 숨김)로 띄워 탭별로 찍는다.
#   실제 기록에는 손대지 않는다. 결과: fastlane/screenshots/ko/
# 사용: ./scripts/screenshots.sh
set -eu
cd "$(dirname "$0")/.."
if [ -z "${DEVELOPER_DIR:-}" ] && xcode-select -p | grep -q CommandLineTools; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

NAME="BabyLog Screenshots (17 Pro Max)"
TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max"
OUT="fastlane/screenshots/ko"
BUNDLE="com.leeyuno.babylog.ios"
DERIVED="build/screenshots"

UDID=$(xcrun simctl list devices available | grep "$NAME" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
if [ -z "$UDID" ]; then
  # 기기 전용 런타임(…-iPhone19-4 등)은 다른 기종을 만들 수 없으므로 일반 iOS 런타임을 고른다
  RUNTIME=$(xcrun simctl list runtimes | grep -E "^iOS" | awk '{print $NF}' | grep -v -- "-iPhone" | tail -1)
  UDID=$(xcrun simctl create "$NAME" "$TYPE" "$RUNTIME")
fi
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
# 시스템 언어·지역을 한국어로 하고 재부팅 (남아 있는 시스템 대화상자도 함께 정리)
xcrun simctl spawn "$UDID" defaults write -g AppleLanguages -array ko
xcrun simctl spawn "$UDID" defaults write -g AppleLocale -string ko_KR
xcrun simctl shutdown "$UDID"
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b >/dev/null

echo "▶ 빌드"
xcodebuild -workspace BabyLog.xcworkspace -scheme BabyLog -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$DERIVED" CODE_SIGN_IDENTITY=- build -quiet
xcrun simctl install "$UDID" "$DERIVED/Build/Products/Debug-iphonesimulator/BabyLog.app"

# 상태 표시줄을 깔끔하게 (9:41, 배터리 가득)
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3 --dataNetwork wifi
xcrun simctl ui "$UDID" appearance light
mkdir -p "$OUT"

shot() {  # shot <파일명> <탭> [기록 시트: feeding|diaper|sleep]
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE" -screenshotDemo -demoTab "$2" -demoAdd "${3:-none}" \
    -display.nightMode off >/dev/null
  sleep 5
  xcrun simctl io "$UDID" screenshot "$OUT/$1.png" >/dev/null
  echo "  ✓ $OUT/$1.png"
}

echo "▶ 촬영"
shot 01-timeline 0
shot 02-add-feeding 0 feeding
shot 03-weekly 1
shot 04-growth 2
xcrun simctl status_bar "$UDID" clear
echo "완료. 위젯·잠금화면 스크린샷은 실제 기기에서 직접 찍어 추가하세요."

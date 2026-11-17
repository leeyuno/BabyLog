# BabyLog Podfile
#
# 설치:  ./scripts/setup.sh   (또는 pod install)
# 이후 반드시 BabyLog.xcworkspace 로 연다 (.xcodeproj 로 열면 Pods 링크 실패)
#
# 타깃 구조는 기존 Pods 통합(Pods-BabyLog / Pods-BabyLogTests / Pods-BabyLog-BabyLogUITests /
# Pods-BabyLogWidgetExtension)과 동일하게 맞춰져 있다. 구조를 바꾸면 pbxproj 의 Pods 설정이 재생성된다.

platform :ios, '16.0'
use_frameworks!

# 버전은 Podfile.lock 과 동일하게 고정 — 업데이트는 의도적으로만 (pod update Google-Mobile-Ads-SDK)
ADMOB_VERSION = '11.5.0'

target 'BabyLog' do
  pod 'Google-Mobile-Ads-SDK', ADMOB_VERSION

  target 'BabyLogTests' do
    inherit! :search_paths
  end

  target 'BabyLogUITests' do
    # 앱의 Pods 를 그대로 상속
  end
end

# 위젯 익스텐션은 광고 SDK 를 사용하지 않는다 (익스텐션에서 AdMob 금지).
target 'BabyLogWidgetExtension' do
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      # Pods 의 최소 배포 타깃을 앱과 맞춰 "deployment target 9.0/11.0 is unsupported" 경고 제거
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
    end
  end
end

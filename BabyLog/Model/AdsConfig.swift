//
//  AdsConfig.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/23.
//
//  AdMob 설정. DEBUG 빌드는 구글 공식 테스트 유닛, RELEASE 빌드는 실제 유닛을 사용한다.
//  ⚠️ 출시 전 Info.plist 의 GADApplicationIdentifier(현재 테스트 앱 ID)도 실제 앱 ID로 교체해야 한다.
//

import Foundation

enum AdsConfig {
    #if DEBUG
    static let bannerUnitID  = "ca-app-pub-3940256099942544/2934735716"   // 테스트 배너
    static let appOpenUnitID = "ca-app-pub-3940256099942544/5575463023"   // 테스트 앱오프닝
    /// true 면 디버그 빌드에서 노출 정책(1일 1회·조용시간 등)을 무시하고 매번 노출 시도
    static let bypassAppOpenRules = false
    #else
    static let bannerUnitID  = "ca-app-pub-8508073786238492/5538132947"
    static let appOpenUnitID = "ca-app-pub-8508073786238492/2441196311"
    static let bypassAppOpenRules = false
    #endif

    /// 정오~정오 창에서 마지막으로 노출한 앵커(epoch 초) 저장 키
    static let kAppOpenLastAnchorTs = "ad_appopen_last_noon_anchor_ts"
    /// 마지막 노출 시각(쿨다운용) 저장 키
    static let kAppOpenLastShownAt = "appopen.lastShownAt"

    /// 새벽 수유 중 광고 노출을 피하기 위한 조용시간
    static let enableQuietHours = true
    static let quietHourRange: ClosedRange<Int> = 0...5   // 00:00 ~ 05:59 (6시는 허용)
}

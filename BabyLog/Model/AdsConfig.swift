//
//  AdsConfig.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/23.


import Foundation

enum AdsConfig {
    // 테스트 유닛: 구글 공식 테스트 ID로 먼저 충분히 테스트하세요.
    static let bannerUnitID      = "ca-app-pub-3940256099942544/2934735716"
//    static let bannerUnitID     = "ca-app-pub-8508073786238492/5538132947"
    static let appOpenUnitID     = "ca-app-pub-3940256099942544/5575463023"
//    static let appOpenUnitID     = "ca-app-pub-8508073786238492/2441196311"

    // 하루 1회 노출 관리 키
//    static let kAppOpenLastShown = "ad_appopen_last_shown" // ISO 날짜 문자열 저장
    static let kAppOpenLastAnchorTs = "ad_appopen_last_noon_anchor_ts"      // 저장 키
    static let enableQuietHours = true
    static let quietHourRange: ClosedRange<Int> = 0...5   // 00:00 ~ 05:59 (6시는 허용)
}


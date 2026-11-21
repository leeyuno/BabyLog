//
//  AdsConfig.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/23.
//
//  AdMob 설정. DEBUG 빌드는 구글 공식 테스트 유닛, RELEASE 빌드는 실제 유닛을 사용한다.
//  ⚠️ 출시 전 Info.plist 의 GADApplicationIdentifier(현재 테스트 앱 ID)도 실제 앱 ID로 교체해야 한다.
//
//  ⚠️ 전면 광고(앱 오프닝·인터스티셜)는 쓰지 않는다 — "정신없는 육아 중 빠른 기록"이라는
//     제품 컨셉과 충돌하기 때문 (CLAUDE.md UX 원칙). 화면을 가리지 않는 형식만 사용.
//

import Foundation

enum AdsConfig {
    #if DEBUG
    static let bannerUnitID = "ca-app-pub-3940256099942544/2934735716"   // 테스트 배너
    #else
    static let bannerUnitID = "ca-app-pub-8508073786238492/5538132947"
    #endif

    /// 광고 표시 여부 — 스크린샷 데모 모드에서는 테스트 광고가 찍히지 않도록 숨긴다
    static var showsAds: Bool {
        #if DEBUG
        return !DemoData.isOn
        #else
        return true
        #endif
    }
}

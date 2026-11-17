//
//  BannerView.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/23.
//
//  AdMob 320x50 배너 (타임라인 목록 하단). 유닛 ID 는 AdsConfig 에서 빌드 구성별로 결정.
//

import SwiftUI
import GoogleMobileAds

struct BannerView: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> GADBannerView {
        let view = GADBannerView(adSize: GADAdSizeBanner) // 320x50
        view.adUnitID = adUnitID
        view.rootViewController = UIApplication.shared
            .connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first
        view.load(GADRequest())
        return view
    }
    func updateUIView(_ uiView: GADBannerView, context: Context) {}
}

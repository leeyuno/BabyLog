
//  AppDelegate.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/23.


import UIKit
import GoogleMobileAds

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        print("Start")
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        // 테스트 기기 등록 예시: 시뮬레이터
        GADMobileAds.sharedInstance().requestConfiguration.testDeviceIdentifiers = []
//        AppOpenAdManager.shared.preload()
        // 필요하다면 차단 로직 주입
//        AppOpenAdManager.shared.shouldShowAd = {
//            // 예) 온보딩 중/기록 편집 중이면 false
//            // return !AppState.shared.isEditing
//            return true
//        }
        return true
    }
}


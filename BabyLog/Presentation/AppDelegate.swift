//
//  AppDelegate.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/23.
//
//  SwiftUI 앱에서 UIKit 생명주기 훅이 필요한 작업(AdMob SDK 초기화)을 담당.
//

import UIKit
import GoogleMobileAds

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        // 실기기 테스트 시 콘솔에 출력되는 테스트 기기 ID 를 여기에 추가
        GADMobileAds.sharedInstance().requestConfiguration.testDeviceIdentifiers = []
        return true
    }
}

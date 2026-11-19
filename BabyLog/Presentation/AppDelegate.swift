//
//  AppDelegate.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/23.
//
//  SwiftUI 앱에서 UIKit 생명주기 훅이 필요한 작업을 담당: AdMob SDK 초기화, Firebase(가족 공유) 설정.
//  GoogleService-Info.plist 가 번들에 없으면(공개 저장소 클론 등) Firebase 를 건너뛰고 가족 공유만 꺼진다.
//

import FirebaseCore
import GoogleMobileAds
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        // 실기기 테스트 시 콘솔에 출력되는 테스트 기기 ID 를 여기에 추가
        GADMobileAds.sharedInstance().requestConfiguration.testDeviceIdentifiers = []

        var backend: FamilyBackend?
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
            backend = FirestoreFamilyBackend()
        }
        FamilySync.shared.configure(backend: backend, container: PersistenceController.shared.container)
        return true
    }
}

//
//  BabyLogApp.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/11.
//
//  앱 진입점.
//  - Core Data viewContext 와 Router 를 환경으로 주입
//  - babylog:// 딥링크(위젯 탭) → Router
//  - 포그라운드 진입 시 앱 오프닝 광고 노출 시도
//

import SwiftUI

@main
struct BabyLogApp: App {
    @StateObject private var router = Router()
    let persistenceController = PersistenceController.shared

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(router)
                .onOpenURL { url in
                    router.handle(url: url)
                }
        }
        .onChange(of: scenePhase) { newPhase in
            guard newPhase == .active else { return }
            AppOpenAdManager.shared.onBecameActive()
            // 화면 구성이 끝난 뒤 표시하도록 약간 지연
            // (AppOpenRules.minActiveSecAfterLaunch 는 이 지연보다 작아야 한다)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                AppOpenAdManager.shared.showIfEligible()
            }
        }
    }
}

//
//  BabyLogApp.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/11.
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
                    print(url)
                    router.handle(url: url)
                }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                AppOpenAdManager.shared.onBecameActive()
                // 약간 늦게 조건 체크 & 표시 시도
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    AppOpenAdManager.shared.showIfEligible()
                }
            }
        }
    }
}

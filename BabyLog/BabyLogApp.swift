//
//  BabyLogApp.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/11.
//
//  앱 진입점.
//  - Core Data viewContext 와 Router 를 환경으로 주입
//  - babylog:// 딥링크(위젯 탭) → Router
//  - 앱 활성화 시 다음 수유 알림 재예약
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
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                FeedReminder.reschedule(context: persistenceController.container.viewContext)
            }
        }
    }
}

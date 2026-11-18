//
//  BabyLogApp.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/11.
//
//  앱 진입점.
//  - Core Data viewContext 와 Router 를 환경으로 주입
//  - babylog:// 딥링크(위젯 탭) → Router
//

import SwiftUI

@main
struct BabyLogApp: App {
    @StateObject private var router = Router()
    let persistenceController = PersistenceController.shared

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(router)
                .onOpenURL { url in
                    router.handle(url: url)
                }
        }
    }
}

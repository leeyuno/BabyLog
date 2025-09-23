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

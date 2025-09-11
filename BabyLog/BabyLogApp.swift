//
//  BabyLogApp.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/11.
//

import SwiftUI

@main
struct BabyLogApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

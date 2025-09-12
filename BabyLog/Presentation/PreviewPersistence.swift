//
//  PreviewPersistence.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/12.
//

import CoreData

enum PreviewPersistence {
    static let controller: PersistenceController = {
        let c = PersistenceController(inMemory: true)
        let viewContext = c.container.viewContext

        // 더미 Baby 생성
        let baby = Baby(context: viewContext)
        baby.id = UUID()
        baby.name = "Preview Baby"

        // 더미 Event 1: 수유
        let feed = CareEvent(context: viewContext)
        feed.id = UUID()
        feed.kind = .feed
        feed.feedType = .breastMilk
        feed.feedAmountML = 80
        feed.createdAt = Date()
        feed.baby = baby

        // 더미 Event 2: 기저귀
        let diaper = CareEvent(context: viewContext)
        diaper.id = UUID()
        diaper.kind = .diaper
        diaper.diaperType = .poop
        diaper.note = "조금 묽음"
        diaper.createdAt = Date().addingTimeInterval(-3600)
        diaper.baby = baby

        try? viewContext.save()
        return c
    }()
}

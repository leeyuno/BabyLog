//
//  LastValueProvider.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/23.
//

import CoreData

enum LastValueProvider {
    /// 해당 아기의 "가장 최근" 수유(Feeding) 이벤트에서 ml을 읽어온다.
    /// 없으면 nil 반환.
    static func lastFeedingML(for baby: Baby, in context: NSManagedObjectContext) -> Int? {
        let req = NSFetchRequest<CareEvent>(entityName: "CareEvent")
        // 성능 위해 kind 조건도 넣고 싶다면, 프로젝트 스키마에 맞춰 조정:
        // - kind가 Int16 raw라면: NSPredicate(format:"baby == %@ AND kindRaw == %d", baby, CareKind.feed.rawValue)
        // - kind가 Transformable/Computed라면 createdAt만 조건에 두고 나중에 필터
        req.predicate = NSPredicate(format: "baby == %@", baby)
        req.sortDescriptors = [NSSortDescriptor(key: #keyPath(CareEvent.createdAt), ascending: false)]
        req.fetchLimit = 20 // 여유롭게 몇 개만 가져와서 코드로 feed만 고르기

        do {
            let events = try context.fetch(req)
            if let lastFeed = events.first(where: { $0.kind == .feed }) {
                return Int(lastFeed.feedAmountML)
            }
            return nil
        } catch {
            print("lastFeedingML fetch error:", error)
            return nil
        }
    }
}

//
//  LastValueProvider.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/23.
//

import CoreData

/// "마지막으로 입력한 값"을 기본값으로 제공 (새 기록 입력 편의 기능)
enum LastValueProvider {
    /// 해당 아기의 가장 최근 수유 이벤트 수유량(ml). 없으면 nil.
    static func lastFeedingML(for baby: Baby, in context: NSManagedObjectContext) -> Int? {
        let req: NSFetchRequest<CareEvent> = CareEvent.fetchRequest()
        // kind 는 Int16 raw(kindRaw)로 저장되므로 DB 레벨에서 바로 필터링 가능
        req.predicate = NSPredicate(format: "baby == %@ AND kindRaw == %d", baby, CareKind.feed.rawValue)
        req.sortDescriptors = [NSSortDescriptor(key: #keyPath(CareEvent.createdAt), ascending: false)]
        req.fetchLimit = 1

        do {
            guard let last = try context.fetch(req).first, last.feedAmountML > 0 else { return nil }
            return Int(last.feedAmountML)
        } catch {
            print("lastFeedingML fetch error:", error)
            return nil
        }
    }

    /// 최근 `limit`회 수유(수유량 > 0)의 평균 ml. 기록이 없으면 nil.
    static func recentAverageFeedingML(for baby: Baby, in context: NSManagedObjectContext,
                                       limit: Int = FeedingGuide.recentSampleCount) -> Double? {
        let req: NSFetchRequest<CareEvent> = CareEvent.fetchRequest()
        req.predicate = NSPredicate(format: "baby == %@ AND kindRaw == %d AND feedAmountML > 0",
                                    baby, CareKind.feed.rawValue)
        req.sortDescriptors = [NSSortDescriptor(key: #keyPath(CareEvent.createdAt), ascending: false)]
        req.fetchLimit = limit

        guard let feeds = try? context.fetch(req), !feeds.isEmpty else { return nil }
        return Double(feeds.reduce(0) { $0 + Int($1.feedAmountML) }) / Double(feeds.count)
    }
}

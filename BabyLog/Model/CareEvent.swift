//
//  CareEvent.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/11.
//

import CoreData

@objc(CareEvent)
public class CareEvent: NSManagedObject {}

extension CareEvent: Identifiable {}

extension CareEvent {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CareEvent> {
        NSFetchRequest<CareEvent>(entityName: "CareEvent")
    }

    @NSManaged public var id: UUID
    @NSManaged public var createdAt: Date
    @NSManaged public var kindRaw: Int16
    @NSManaged public var feedTypeRaw: Int16
    @NSManaged public var feedAmountML: Int32
    @NSManaged public var diaperTypeRaw: Int16
    @NSManaged public var sleepStartAt: Date?
    @NSManaged public var sleepEndAt: Date?
    @NSManaged public var note: String?
    @NSManaged public var baby: Baby
}

// 편의 computed properties
extension CareEvent {
    var kind: CareKind {
        get { CareKind(rawValue: kindRaw) ?? .feed }
        set { kindRaw = newValue.rawValue }
    }

    var feedType: FeedType? {
        get { FeedType(rawValue: feedTypeRaw) }
        set { feedTypeRaw = newValue?.rawValue ?? Int16.min }
    }

    var diaperType: DiaperType? {
        get { DiaperType(rawValue: diaperTypeRaw) }
        set { diaperTypeRaw = newValue?.rawValue ?? Int16.min }
    }

    var sleepDurationMinutes: Int? {
        guard let s = sleepStartAt, let e = sleepEndAt else { return nil }
        return Int(e.timeIntervalSince(s) / 60)
    }
}

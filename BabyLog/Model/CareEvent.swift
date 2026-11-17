//
//  CareEvent.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/11.
//

import CoreData

/// 육아 기록 1건 (수유 / 기저귀 / 수면).
/// - `createdAt`: 타임라인 정렬·일별 집계의 기준 시각.
///   수면은 종료 시각(진행중이면 시작 시각)을 넣는다 — AddEventView 참고.
/// - kind 별로 의미 있는 필드만 채워지고 나머지는 기본값(0 / nil)이다.
/// - 모델 파일은 Codegen=Manual 이므로 속성 추가 시 xcdatamodel 과 이 파일을 함께 수정할 것.
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

// 편의 computed properties: Int16 raw 값 ↔ enum 변환
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

    /// 종료된 수면의 길이(분). 진행중이면 nil.
    var sleepDurationMinutes: Int? {
        guard let s = sleepStartAt, let e = sleepEndAt else { return nil }
        return Int(e.timeIntervalSince(s) / 60)
    }
}

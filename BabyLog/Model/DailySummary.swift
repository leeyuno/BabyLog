//
//  DailySummary.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/23.
//
//  ⚠️ 이 파일은 앱(BabyLog)과 위젯(BabyLogWidgetExtension) 두 타깃에 모두 포함된다.
//  - 앱/위젯이 공유하는 상수(App Group, 스토어 경로)
//  - 위젯 프로세스용 Core Data 접근 헬퍼
//  - 일별 집계 로직(주간 개요 화면 · 위젯이 동일한 계산을 쓰도록 단일화)
//  UIKit/GoogleMobileAds 등 앱 전용 의존성을 import 하지 말 것.
//

import Foundation
import CoreData

// MARK: - App Group 공유 상수

enum BabyLogGroup {
    /// 앱·위젯 엔타이틀먼트(com.apple.security.application-groups)와 반드시 일치해야 한다.
    static let appGroupId = "group.com.leeyuno.babylog.ios"

    /// 공유 SQLite 스토어 위치.
    /// App Group 엔타이틀먼트가 없는 타깃에서는 nil 이 반환된다 (강제 언래핑 금지).
    static var storeURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupId)?
            .appendingPathComponent("BabyLog.sqlite")
    }
}

// MARK: - Core Data 모델 (프로세스당 1회 로드)

enum CoreDataModel {
    /// `NSManagedObjectModel`을 프로세스 전체에서 하나만 사용한다.
    /// 컨테이너마다 모델을 새로 로드하면 "Multiple NSEntityDescriptions claim the
    /// NSManagedObject subclass" 경고와 함께 엔티티 해석이 모호해질 수 있다(테스트·프리뷰에서 특히).
    static let shared: NSManagedObjectModel = {
        guard let url = Bundle(for: CareEvent.self).url(forResource: "BabyLog", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: url) else {
            fatalError("BabyLog.momd 를 번들에서 찾을 수 없습니다.")
        }
        return model
    }()
}

// MARK: - 위젯용 읽기 전용 접근

enum SharedPersistence {
    /// 위젯 프로세스에서 재사용하는 컨테이너. 타임라인 갱신마다 새로 만들지 않는다.
    /// App Group 접근 불가·스토어 로드 실패 시 nil.
    static let widgetContainer: NSPersistentContainer? = {
        guard let url = BabyLogGroup.storeURL else {
            print("[SharedPersistence] App Group 컨테이너에 접근할 수 없습니다. 위젯 엔타이틀먼트를 확인하세요.")
            return nil
        }
        let container = NSPersistentContainer(name: "BabyLog", managedObjectModel: CoreDataModel.shared)
        container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: url)]

        // 기본값(shouldAddStoreAsynchronously == false)이라 콜백은 동기적으로 호출된다.
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError {
            print("[SharedPersistence] 스토어 로드 실패:", loadError)
            return nil
        }
        return container
    }()

    /// 매 호출마다 새 백그라운드 컨텍스트에서 읽는다.
    /// (컨텍스트를 재사용하면 앱이 갱신한 값이 캐시 때문에 반영되지 않을 수 있음)
    static func read<T>(_ block: (NSManagedObjectContext) -> T) -> T? {
        guard let container = widgetContainer else { return nil }
        let context = container.newBackgroundContext()
        var result: T?
        context.performAndWait { result = block(context) }
        return result
    }

    /// 첫 번째 아기(이름순). 현재 앱은 단일 아기만 지원한다.
    static func firstBaby(in context: NSManagedObjectContext) -> Baby? {
        let req: NSFetchRequest<Baby> = Baby.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: #keyPath(Baby.name), ascending: true)]
        req.fetchLimit = 1
        return (try? context.fetch(req))?.first
    }
}

// MARK: - 일별 집계

/// 하루치 집계 결과. `day`는 해당 날짜의 startOfDay.
struct DayTotals: Equatable {
    let day: Date
    var feedML: Int = 0
    /// 종료된 수면만 합산(진행중 수면 제외). 이벤트의 `createdAt` 날짜에 귀속된다.
    var sleepMinutes: Double = 0
    /// 대변 + 혼합 기저귀 횟수 (소변만은 제외)
    var poopCount: Int = 0

    var sleepHours: Double { sleepMinutes / 60.0 }
}

enum CareStats {
    /// 오늘을 포함한 최근 `count`일의 startOfDay 배열 (오름차순, 마지막이 오늘).
    static func recentDays(_ count: Int = 7, now: Date = Date(), calendar: Calendar = .current) -> [Date] {
        let today = calendar.startOfDay(for: now)
        return (0..<count).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }
    }

    /// `days` 범위에 속하는 이벤트를 `createdAt` 기준 날짜별로 합산한다.
    /// 범위 밖 이벤트는 무시하며, 반환 배열은 `days`와 순서·길이가 같다.
    static func aggregate(events: [CareEvent], days: [Date], calendar: Calendar = .current) -> [DayTotals] {
        var map = Dictionary(uniqueKeysWithValues: days.map { ($0, DayTotals(day: $0)) })

        for e in events {
            let key = calendar.startOfDay(for: e.createdAt)
            guard var t = map[key] else { continue }
            switch e.kind {
            case .feed:
                t.feedML += Int(e.feedAmountML)
            case .diaper:
                if e.diaperType == .poop || e.diaperType == .mixed { t.poopCount += 1 }
            case .sleep:
                if let s = e.sleepStartAt, let end = e.sleepEndAt, end > s {
                    t.sleepMinutes += end.timeIntervalSince(s) / 60.0
                }
            }
            map[key] = t
        }
        return days.map { map[$0] ?? DayTotals(day: $0) }
    }

    /// 특정 아기의 [from, to) 구간 이벤트 조회 (createdAt 오름차순).
    static func fetchEvents(for baby: Baby, from: Date, to: Date,
                            in context: NSManagedObjectContext) -> [CareEvent] {
        let req: NSFetchRequest<CareEvent> = CareEvent.fetchRequest()
        req.predicate = NSPredicate(format: "baby == %@ AND createdAt >= %@ AND createdAt < %@",
                                    baby, from as NSDate, to as NSDate)
        req.sortDescriptors = [NSSortDescriptor(key: #keyPath(CareEvent.createdAt), ascending: true)]
        return (try? context.fetch(req)) ?? []
    }

    static func average(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }
}

// MARK: - 오늘 vs 직전 6일 평균 요약

struct DailySummary: Equatable {
    let date: Date
    let sleepMinutes: Double
    let feedingML: Double
    let diaperCount: Double
    let avgSleepMinutes6: Double
    let avgFeedingML6: Double
    let avgDiaperCount6: Double
}

extension DailySummary {
    /// 7일 집계(마지막 요소 = 오늘)로부터 요약을 만든다. 평균은 오늘을 제외한 앞 6일.
    init(totals: [DayTotals], date: Date = Date()) {
        let today = totals.last ?? DayTotals(day: date)
        let previous = Array(totals.dropLast())
        self.init(
            date: date,
            sleepMinutes: today.sleepMinutes,
            feedingML: Double(today.feedML),
            diaperCount: Double(today.poopCount),
            avgSleepMinutes6: CareStats.average(previous.map(\.sleepMinutes)),
            avgFeedingML6: CareStats.average(previous.map { Double($0.feedML) }),
            avgDiaperCount6: CareStats.average(previous.map { Double($0.poopCount) })
        )
    }

    /// Core Data에서 직접 계산한다. 아기가 없으면 nil.
    static func make(in context: NSManagedObjectContext, now: Date = Date(),
                     calendar: Calendar = .current) -> DailySummary? {
        guard let baby = SharedPersistence.firstBaby(in: context) else { return nil }
        let days = CareStats.recentDays(7, now: now, calendar: calendar)
        guard let start = days.first,
              let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else { return nil }
        let events = CareStats.fetchEvents(for: baby, from: start, to: end, in: context)
        return DailySummary(totals: CareStats.aggregate(events: events, days: days, calendar: calendar), date: now)
    }

    static var mock: DailySummary {
        .init(date: Date(),
              sleepMinutes: 460, feedingML: 780, diaperCount: 4,
              avgSleepMinutes6: 425, avgFeedingML6: 720, avgDiaperCount6: 3.2)
    }
}

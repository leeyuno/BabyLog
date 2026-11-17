//
//  BabyLogTests.swift
//  BabyLogTests
//
//  Created by 이윤오 on 2025/09/11.
//
//  순수 로직 단위 테스트: 딥링크 파싱, 일별 집계(CareStats), DailySummary, 마지막 수유량, 수유량 자동 추천.
//  Core Data 는 PersistenceController(inMemory: true) 를 사용한다.
//

import XCTest
import CoreData
@testable import BabyLog

final class BabyLogTests: XCTestCase {

    private var context: NSManagedObjectContext!
    private var baby: Baby!
    private let cal = Calendar.current

    override func setUpWithError() throws {
        context = PersistenceController(inMemory: true).container.viewContext
        baby = Baby(context: context)
        baby.id = UUID()
        baby.name = "Test"
    }

    override func tearDownWithError() throws {
        context = nil
        baby = nil
    }

    // MARK: - Helpers

    @discardableResult
    private func makeEvent(_ kind: CareKind, at date: Date,
                           ml: Int32 = 0, diaper: DiaperType? = nil,
                           sleepMinutes: Double? = nil) -> CareEvent {
        let e = CareEvent(context: context)
        e.id = UUID()
        e.kind = kind
        e.baby = baby
        e.createdAt = date
        e.feedType = kind == .feed ? .formula : nil
        e.feedAmountML = ml
        e.diaperType = diaper
        if let m = sleepMinutes {
            e.sleepStartAt = date.addingTimeInterval(-m * 60)
            e.sleepEndAt = date
        }
        return e
    }

    // MARK: - Router

    func testRouterParsesAddKinds() {
        let router = Router()
        router.handle(url: URL(string: "babylog://add?type=sleep")!)
        XCTAssertEqual(router.route, .add(.sleep))
        router.handle(url: URL(string: "babylog://add?type=diaper")!)
        XCTAssertEqual(router.route, .add(.diaper))
    }

    func testRouterAcceptsLegacyFeedAlias() {
        let router = Router()
        router.handle(url: URL(string: "babylog://add?type=feed")!)
        XCTAssertEqual(router.route, .add(.feeding))
    }

    func testRouterIgnoresForeignScheme() {
        let router = Router()
        router.handle(url: URL(string: "https://add?type=sleep")!)
        XCTAssertEqual(router.route, .none)
    }

    func testDeepLinkRoundTrip() {
        for kind in AddKind.allCases {
            let router = Router()
            router.handle(url: DeepLink.add(kind))
            XCTAssertEqual(router.route, .add(kind))
        }
    }

    // MARK: - CareStats

    func testRecentDaysEndsTodayAscending() {
        let days = CareStats.recentDays(7)
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.last, cal.startOfDay(for: Date()))
        XCTAssertEqual(days, days.sorted())
    }

    func testAggregateSumsByDay() throws {
        let days = CareStats.recentDays(7)
        let today = try XCTUnwrap(days.last).addingTimeInterval(10 * 3600)       // 오늘 10시
        let yesterday = days[5].addingTimeInterval(10 * 3600)

        makeEvent(.feed, at: today, ml: 100)
        makeEvent(.feed, at: today, ml: 50)
        makeEvent(.diaper, at: today, diaper: .pee)     // 배변 아님
        makeEvent(.diaper, at: today, diaper: .poop)
        makeEvent(.diaper, at: today, diaper: .mixed)
        makeEvent(.sleep, at: today, sleepMinutes: 90)
        makeEvent(.feed, at: yesterday, ml: 70)
        makeEvent(.feed, at: days[0].addingTimeInterval(-3600), ml: 999) // 범위 밖

        let req: NSFetchRequest<CareEvent> = CareEvent.fetchRequest()
        let events = try context.fetch(req)
        let totals = CareStats.aggregate(events: events, days: days)

        XCTAssertEqual(totals.last?.feedML, 150)
        XCTAssertEqual(totals.last?.poopCount, 2)
        XCTAssertEqual(totals.last?.sleepMinutes ?? 0, 90, accuracy: 0.001)
        XCTAssertEqual(totals[5].feedML, 70)
        XCTAssertEqual(totals.reduce(0) { $0 + $1.feedML }, 220)
    }

    func testOngoingSleepIsExcluded() {
        let days = CareStats.recentDays(1)
        let e = makeEvent(.sleep, at: days[0].addingTimeInterval(3600))
        e.sleepStartAt = e.createdAt
        e.sleepEndAt = nil
        XCTAssertEqual(CareStats.aggregate(events: [e], days: days).first?.sleepMinutes, 0)
    }

    // MARK: - DailySummary

    func testDailySummaryAveragesPreviousSixDays() {
        let days = CareStats.recentDays(7)
        var totals = days.map { DayTotals(day: $0) }
        for i in 0..<6 { totals[i].feedML = 60 * (i + 1) }   // 60..360 → 평균 210
        totals[6].feedML = 500

        let s = DailySummary(totals: totals)
        XCTAssertEqual(s.feedingML, 500)
        XCTAssertEqual(s.avgFeedingML6, 210, accuracy: 0.001)
    }

    // MARK: - LastValueProvider

    func testLastFeedingMLReturnsMostRecentFeed() {
        let now = Date()
        makeEvent(.feed, at: now.addingTimeInterval(-7200), ml: 80)
        makeEvent(.feed, at: now.addingTimeInterval(-3600), ml: 120)
        makeEvent(.diaper, at: now, diaper: .pee)   // 더 최근이지만 수유 아님
        XCTAssertEqual(LastValueProvider.lastFeedingML(for: baby, in: context), 120)
    }

    func testLastFeedingMLNilWhenNoFeeds() {
        XCTAssertNil(LastValueProvider.lastFeedingML(for: baby, in: context))
    }

    // MARK: - FeedingGuide (수유량 자동 추천)

    func testFeedsPerDayByAge() {
        XCTAssertEqual(FeedingGuide.feedsPerDay(ageMonths: 0), 8)
        XCTAssertEqual(FeedingGuide.feedsPerDay(ageMonths: 1), 7)
        XCTAssertEqual(FeedingGuide.feedsPerDay(ageMonths: 3), 6)
        XCTAssertEqual(FeedingGuide.feedsPerDay(ageMonths: 5), 5)
        XCTAssertEqual(FeedingGuide.feedsPerDay(ageMonths: 10), 4)
    }

    func testRecommendedPerFeed() {
        // 4kg, 1개월: 600ml ÷ 7 = 85.7 → 90
        XCTAssertEqual(FeedingGuide.recommendedPerFeedML(weightKg: 4, ageMonths: 1), 90)
        // 6kg, 3개월: 900 ÷ 6 = 150
        XCTAssertEqual(FeedingGuide.recommendedPerFeedML(weightKg: 6, ageMonths: 3), 150)
        // 9kg, 7개월: 1350 → 상한 1000 ÷ 4 = 250
        XCTAssertEqual(FeedingGuide.recommendedPerFeedML(weightKg: 9, ageMonths: 7), 250)
    }

    func testRecommendedNilWithoutInputs() {
        XCTAssertNil(FeedingGuide.recommendedPerFeedML(weightKg: 0, ageMonths: 2))
        XCTAssertNil(FeedingGuide.recommendedPerFeedML(weightKg: 5, ageMonths: nil))
    }

    func testDefaultAmountManualModeUsesLast() {
        XCTAssertEqual(FeedingGuide.defaultFeedAmount(lastML: 80, recentAverageML: 70,
                                                      recommendedML: 150, autoRecommend: false), 80)
        XCTAssertEqual(
            FeedingGuide.defaultFeedAmount(lastML: nil, recentAverageML: nil, recommendedML: 150, autoRecommend: false),
            FeedingGuide.fallbackML
        )
    }

    func testDefaultAmountAutoModeRaisesWhenAverageIsLow() {
        XCTAssertEqual(FeedingGuide.defaultFeedAmount(lastML: 100, recentAverageML: 90,
                                                      recommendedML: 150, autoRecommend: true), 150)
    }

    func testDefaultAmountAutoModeKeepsLastWhenAverageIsEnough() {
        XCTAssertEqual(FeedingGuide.defaultFeedAmount(lastML: 170, recentAverageML: 160,
                                                      recommendedML: 150, autoRecommend: true), 170)
    }

    func testDefaultAmountAutoModeWithoutHistoryOrProfile() {
        XCTAssertEqual(FeedingGuide.defaultFeedAmount(lastML: nil, recentAverageML: nil,
                                                      recommendedML: 120, autoRecommend: true), 120)
        // 체중 미입력 → 수동과 동일
        XCTAssertEqual(FeedingGuide.defaultFeedAmount(lastML: 80, recentAverageML: 80,
                                                      recommendedML: nil, autoRecommend: true), 80)
    }

    func testBabyAgeFromBirthdayOrManual() {
        baby.birthday = cal.date(byAdding: .month, value: -3, to: Date())
        XCTAssertEqual(baby.ageInMonths, 3)
        baby.birthday = nil
        baby.manualAgeMonths = -1
        XCTAssertNil(baby.ageInMonths)
        baby.manualAgeMonths = 5
        XCTAssertEqual(baby.ageInMonths, 5)
    }

    func testRecentAverageFeedingML() {
        let now = Date()
        for (i, ml) in [100, 120, 140, 160, 180, 999].enumerated() {
            // i 가 클수록 과거 → 최근 5회는 100~180
            makeEvent(.feed, at: now.addingTimeInterval(Double(-i) * 3600), ml: Int32(ml))
        }
        XCTAssertEqual(LastValueProvider.recentAverageFeedingML(for: baby, in: context) ?? 0, 140, accuracy: 0.001)
    }
}

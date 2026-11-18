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

    // MARK: - 성장 기록 (GrowthMath / GrowthStore)

    func testAgeMonthsFractional() throws {
        let birthday = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 1, day: 1)))
        let at = try XCTUnwrap(cal.date(byAdding: .day, value: 61, to: birthday))
        XCTAssertEqual(GrowthMath.ageMonths(birthday: birthday, at: at), 61 / 30.4375, accuracy: 0.0001)
        XCTAssertEqual(GrowthMath.ageMonths(birthday: at, at: birthday), 0)  // 생일 이전은 0
    }

    func testAgeText() throws {
        let birthday = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 8, day: 5)))
        let now1 = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 11, day: 17)))
        let now2 = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 8, day: 20)))
        XCTAssertEqual(GrowthMath.ageText(birthday: birthday, now: now1), "3개월 12일")
        XCTAssertEqual(GrowthMath.ageText(birthday: birthday, now: now2), "생후 15일")
    }

    func testWeightUpsertSameDayAndSyncLatest() throws {
        let today = Date()
        let lastWeek = try XCTUnwrap(cal.date(byAdding: .day, value: -7, to: today))
        GrowthStore.upsert(weightKg: 5.8, on: lastWeek, for: baby, in: context)
        GrowthStore.upsert(weightKg: 6.1, on: today, for: baby, in: context)
        GrowthStore.upsert(weightKg: 6.2, on: today.addingTimeInterval(-60), for: baby, in: context) // 같은 날 → 갱신

        let records = GrowthStore.records(for: baby, in: context)
        XCTAssertEqual(records.map(\.weightKg), [5.8, 6.2])
        XCTAssertEqual(baby.weightKg, 6.2)  // 최신 기록이 프로필 몸무게(수유 추천 입력값)가 됨
    }

    func testWeightDeleteFallsBackToPreviousRecord() throws {
        let today = Date()
        let lastWeek = try XCTUnwrap(cal.date(byAdding: .day, value: -7, to: today))
        GrowthStore.upsert(weightKg: 5.8, on: lastWeek, for: baby, in: context)
        let latest = GrowthStore.upsert(weightKg: 6.2, on: today, for: baby, in: context)
        GrowthStore.delete(latest, of: baby, in: context)
        XCTAssertEqual(baby.weightKg, 5.8)
    }

    func testSeedFromSettingsWeightOnlyOnce() {
        baby.weightKg = 4.9
        XCTAssertTrue(GrowthStore.seedIfNeeded(for: baby, in: context))
        XCTAssertFalse(GrowthStore.seedIfNeeded(for: baby, in: context))
        XCTAssertEqual(GrowthStore.records(for: baby, in: context).count, 1)
    }

    // MARK: - 다음 수유 예상 (FeedSchedule)

    func testPredictUsesMedianInterval() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        // 3시간, 3시간, 6시간(밤잠) 간격 → 중앙값 3시간
        let times = [-12, -9, -6, 0].map { now.addingTimeInterval(Double($0) * 3600 - 600) }
        let p = try XCTUnwrap(FeedSchedule.predict(feedTimes: times, now: now))
        XCTAssertEqual(p.interval, 3 * 3600, accuracy: 0.1)
        XCTAssertEqual(p.next, times.last!.addingTimeInterval(3 * 3600))  // swiftlint:disable:this force_unwrapping
    }

    func testPredictMergesFeedsWithin30Minutes() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        // 모유 후 20분 뒤 분유 보충 → 한 번으로
        let offsets: [Double] = [-6 * 60, -3 * 60, -3 * 60 + 20, -10]
        let times = offsets.map { now.addingTimeInterval($0 * 60) }
        let p = try XCTUnwrap(FeedSchedule.predict(feedTimes: times, now: now))
        XCTAssertEqual(p.lastFeed, times[3])
        XCTAssertEqual(FeedSchedule.intervalText(p.interval), "2시간 55분")
    }

    func testPredictNeedsThreeSessionsWithin48h() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertNil(FeedSchedule.predict(feedTimes: [now.addingTimeInterval(-3600), now], now: now))
        let old = [-60, -57, -54].map { now.addingTimeInterval(Double($0) * 3600) }  // 48시간 밖
        XCTAssertNil(FeedSchedule.predict(feedTimes: old, now: now))
    }

    func testReminderFireDate() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let p = FeedSchedule.Prediction(lastFeed: now.addingTimeInterval(-3600), interval: 3 * 3600)
        XCTAssertEqual(FeedReminder.fireDate(prediction: p, leadMinutes: 10, now: now),
                       now.addingTimeInterval(2 * 3600 - 600))
        let late = FeedSchedule.Prediction(lastFeed: now.addingTimeInterval(-4 * 3600), interval: 3 * 3600)
        XCTAssertNil(FeedReminder.fireDate(prediction: late, leadMinutes: 0, now: now))  // 이미 지남
    }

    // MARK: - 모유 좌/우 타이머

    func testBreastTimerToggleSwitchAndPause() {
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        var timer = BreastTimer()
        timer.toggle(.left, now: t0)
        timer.toggle(.right, now: t0.addingTimeInterval(300))           // 왼 5분 후 오른쪽으로
        XCTAssertEqual(timer.seconds(.right, now: t0.addingTimeInterval(420)), 120)
        timer.toggle(.right, now: t0.addingTimeInterval(480))           // 오른쪽 일시정지
        XCTAssertFalse(timer.isRunning)
        XCTAssertEqual(timer.leftSec, 300)
        XCTAssertEqual(timer.rightSec, 180)
        XCTAssertEqual(timer.lastSide, .right)
        XCTAssertEqual(timer.firstStartedAt, t0)
    }

    func testBreastTimerManualAdjustNeverNegative() {
        var timer = BreastTimer()
        timer.adjust(.left, minutes: 1)
        timer.adjust(.left, minutes: -3)
        XCTAssertEqual(timer.leftSec, 0)
        XCTAssertEqual(timer.lastSide, .left)
    }

    func testLastFeedingMLSkipsDirectBreastfeeding() {
        let now = Date()
        makeEvent(.feed, at: now.addingTimeInterval(-3600), ml: 120)
        let breast = makeEvent(.feed, at: now)
        breast.feedType = .breastMilk
        breast.breastLeftSec = 600
        breast.lastBreastSide = .left
        XCTAssertEqual(LastValueProvider.lastFeedingML(for: baby, in: context), 120)
        XCTAssertEqual(LastValueProvider.lastBreastSide(for: baby, in: context), .left)
        XCTAssertEqual(EventRowView.breastSummary(left: 600, right: 0, last: .left), "왼 10분 · 오 0분 (총 10분) · 왼쪽에서 끝")
    }

    // MARK: - WHO 성장곡선 (CDC 배포 WHO 표의 백분위 값과 대조)

    func testWHOWeightMatchesPublishedPercentiles() throws {
        let z5 = -1.6448536, z95 = 1.6448536
        let boys0 = try XCTUnwrap(WHOGrowth.lms(sex: .boy, months: 0))
        XCTAssertEqual(WHOGrowth.weight(z: z5, lms: boys0), 2.603994, accuracy: 0.0005)
        XCTAssertEqual(WHOGrowth.weight(z: z95, lms: boys0), 4.214527, accuracy: 0.0005)
        let girls1 = try XCTUnwrap(WHOGrowth.lms(sex: .girl, months: 1))
        XCTAssertEqual(WHOGrowth.weight(z: z5, lms: girls1), 3.326209, accuracy: 0.0005)
        XCTAssertEqual(WHOGrowth.weight(z: z95, lms: girls1), 5.225436, accuracy: 0.0005)
    }

    func testWHOPercentile() throws {
        XCTAssertEqual(try XCTUnwrap(WHOGrowth.percentile(weight: 9.6479, sex: .boy, months: 12)), 50, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(WHOGrowth.percentile(weight: 2.603994, sex: .boy, months: 0)), 5, accuracy: 0.05)
        XCTAssertNil(WHOGrowth.percentile(weight: 10, sex: .unknown, months: 12))
        XCTAssertNil(WHOGrowth.percentile(weight: 10, sex: .girl, months: 30))   // 24개월 초과
    }

    func testWHOInterpolatesBetweenMonths() throws {
        let mid = try XCTUnwrap(WHOGrowth.lms(sex: .girl, months: 2.5))
        XCTAssertEqual(mid.m, (5.1282 + 5.8458) / 2, accuracy: 0.00001)
    }
}

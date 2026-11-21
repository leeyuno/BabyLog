//
//  DemoData.swift
//  BabyLog
//
//  Created by 이윤오 on 2026/11/20.
//
//  앱스토어 스크린샷용 데모 모드 (DEBUG 빌드 전용, 앱 타깃 전용).
//  실행 인자 `-screenshotDemo` 를 주면 실제 스토어 대신 인메모리 스토어에 1주일치 기록을 채우고 광고를 숨긴다.
//  `-demoTab 0~3` 으로 시작 탭, `-demoAdd feeding` 으로 기록 시트를 고른다. 사용법: scripts/screenshots.sh
//  ⚠️ 릴리스 빌드에는 컴파일되지 않는다 (#if DEBUG). 사용자의 실제 데이터는 건드리지 않는다.
//

#if DEBUG
import CoreData
import Foundation

enum DemoData {
    static var isOn: Bool { ProcessInfo.processInfo.arguments.contains("-screenshotDemo") }

    /// 시작 탭 (0 타임라인 · 1 주간 개요 · 2 성장 · 3 설정)
    static var initialTab: Int { UserDefaults.standard.integer(forKey: "demoTab") }

    /// 시작하자마자 띄울 기록 시트 (`-demoAdd feeding|diaper|sleep`)
    static var initialAdd: AddKind? {
        UserDefaults.standard.string(forKey: "demoAdd").flatMap(AddKind.init(rawValue:))
    }

    static func makeController(now: Date = Date()) -> PersistenceController {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let baby = makeBaby(now: now, in: context)
        addWeights(for: baby, now: now, in: context)
        addWeek(for: baby, now: now, in: context)
        do {
            try context.save()
        } catch {
            assertionFailure("데모 데이터 저장 실패: \(error)")
        }
        return controller
    }

    private static let calendar = Calendar.current

    private static func makeBaby(now: Date, in context: NSManagedObjectContext) -> Baby {
        let baby = Baby(context: context)
        baby.id = UUID()
        baby.name = "하늘"
        baby.birthday = calendar.date(byAdding: .day, value: -100, to: now)
        baby.sexRaw = BabySex.girl.rawValue
        baby.manualAgeMonths = -1
        return baby
    }

    /// 출생 3.2kg → 100일 6.3kg (WHO 여아 중앙값 근처)
    private static func addWeights(for baby: Baby, now: Date, in context: NSManagedObjectContext) {
        let points: [(daysAgo: Int, kg: Double)] = [
            (100, 3.2), (86, 3.6), (70, 4.3), (55, 4.9), (40, 5.4), (20, 5.9), (0, 6.3),
        ]
        for point in points {
            guard let date = calendar.date(byAdding: .day, value: -point.daysAgo, to: now) else { continue }
            GrowthStore.upsert(weightKg: point.kg, on: date, for: baby, in: context)
        }
    }

    /// 최근 7일: 약 3시간 간격 수유, 기저귀 하루 6~7회, 낮잠·밤잠. 마지막 수유는 약 1시간 40분 전.
    private static func addWeek(for baby: Baby, now: Date, in context: NSManagedObjectContext) {
        let lastFeed = now.addingTimeInterval(-100 * 60)
        let amounts: [Int32] = [140, 120, 150, 130, 160, 120, 140, 150]
        var feedTime = lastFeed
        var index = 0
        while feedTime > now.addingTimeInterval(-7 * 86_400) {
            let isDirect = index % 5 == 2   // 가끔 모유 직접 수유
            let ev = event(.feed, at: feedTime, baby: baby, in: context)
            ev.feedTypeRaw = isDirect ? FeedType.breastMilk.rawValue : FeedType.formula.rawValue
            ev.feedAmountML = isDirect ? 0 : amounts[index % amounts.count]
            if isDirect {
                ev.breastLeftSec = 9 * 60
                ev.breastRightSec = 7 * 60
                ev.breastLastSide = BreastSide.right.rawValue
            }
            // 수유 30분 뒤 기저귀 (두 번 중 한 번은 대변 포함)
            let diaper = event(.diaper, at: feedTime.addingTimeInterval(30 * 60), baby: baby, in: context)
            diaper.diaperTypeRaw = index % 3 == 0 ? DiaperType.poop.rawValue : DiaperType.pee.rawValue
            // 수유 40분 뒤부터 낮잠 (밤에는 길게)
            let hour = calendar.component(.hour, from: feedTime)
            let sleepMinutes: Double = (hour >= 21 || hour < 5) ? 150 : 70
            let start = feedTime.addingTimeInterval(40 * 60)
            let end = start.addingTimeInterval(sleepMinutes * 60)
            if end < now {
                let sleep = event(.sleep, at: end, baby: baby, in: context)
                sleep.sleepStartAt = start
                sleep.sleepEndAt = end
            }
            index += 1
            feedTime = feedTime.addingTimeInterval(-Double(170 + (index % 3) * 10) * 60)
        }
    }

    private static func event(
        _ kind: CareKind,
        at date: Date,
        baby: Baby,
        in context: NSManagedObjectContext
    ) -> CareEvent {
        let ev = CareEvent(context: context)
        ev.id = UUID()
        ev.kindRaw = kind.rawValue
        ev.feedTypeRaw = Int16.min
        ev.diaperTypeRaw = Int16.min
        ev.breastLastSide = -1
        ev.createdAt = date
        ev.baby = baby
        return ev
    }
}
#endif

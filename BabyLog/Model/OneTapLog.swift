//
//  OneTapLog.swift
//  BabyLog
//
//  Created by 이윤오 on 2026/11/18.
//
//  원탭 기록: 위젯에서 앱을 열지 않고 바로 저장하는 동작 (앱·위젯 두 타깃에 포함 — 앱 전용 심볼 금지).
//  Android lib/domain/one_tap.dart 와 같은 규칙.
//    pee / poop  → 기저귀 기록 (지금)
//    formula     → 분유, 직전 "ml 있는" 수유량 (없으면 60ml)
//    sleep       → 자는 중인 수면이 있으면 지금 시각으로 종료("깼어요"), 없으면 지금부터 수면 시작("잠들었어요")
//  기록 시각 규칙은 앱과 동일 (수면은 종료/시작 시각이 createdAt).
//

import CoreData
import Foundation

enum OneTapAction: String, CaseIterable {
    case pee, poop, formula, sleep
}

enum OneTapLog {
    static let defaultFormulaML = 60
    /// 마지막 원탭 결과 문구 (위젯에 "✓ 14:05 소변 기록" 으로 표시) — App Group UserDefaults
    static let lastResultKey = "onetap.lastResult"

    struct Status: Equatable {
        var formulaML: Int
        /// 자는 중이면 잠든 시각
        var sleepingSince: Date?
    }

    static func status(for baby: Baby, in context: NSManagedObjectContext) -> Status {
        Status(formulaML: lastFormulaML(for: baby, in: context) ?? defaultFormulaML,
               sleepingSince: ongoingSleep(for: baby, in: context)?.sleepStartAt)
    }

    /// 동작을 수행하고 결과 문구를 돌려준다. 저장(save)은 호출 측에서.
    @discardableResult
    static func perform(_ action: OneTapAction, baby: Baby, in context: NSManagedObjectContext,
                        now: Date = Date()) -> String {
        switch action {
        case .pee, .poop:
            let ev = newEvent(.diaper, baby: baby, in: context, at: now)
            ev.diaperType = action == .pee ? .pee : .poop
            return "\(timeText(now)) \(action == .pee ? "소변" : "대변") 기록"
        case .formula:
            let ml = lastFormulaML(for: baby, in: context) ?? defaultFormulaML
            let ev = newEvent(.feed, baby: baby, in: context, at: now)
            ev.feedType = .formula
            ev.feedAmountML = Int32(ml)
            return "\(timeText(now)) 분유 \(ml)ml 기록"
        case .sleep:
            if let sleeping = ongoingSleep(for: baby, in: context) {
                sleeping.sleepEndAt = now
                sleeping.createdAt = now       // 수면 기준 시각 = 종료 시각
                return "\(timeText(now)) 깼어요 기록"
            }
            let ev = newEvent(.sleep, baby: baby, in: context, at: now)
            ev.sleepStartAt = now
            return "\(timeText(now)) 잠들었어요 기록"
        }
    }

    // MARK: - 조회

    /// 직전 "ml 있는" 수유량
    static func lastFormulaML(for baby: Baby, in context: NSManagedObjectContext) -> Int? {
        let req: NSFetchRequest<CareEvent> = CareEvent.fetchRequest()
        req.predicate = NSPredicate(format: "baby == %@ AND kindRaw == %d AND feedAmountML > 0",
                                    baby, CareKind.feed.rawValue)
        req.sortDescriptors = [NSSortDescriptor(key: #keyPath(CareEvent.createdAt), ascending: false)]
        req.fetchLimit = 1
        return (try? context.fetch(req))?.first.map { Int($0.feedAmountML) }
    }

    /// 가장 최근의 자는 중 수면 (종료 시각 없음)
    static func ongoingSleep(for baby: Baby, in context: NSManagedObjectContext) -> CareEvent? {
        let req: NSFetchRequest<CareEvent> = CareEvent.fetchRequest()
        req.predicate = NSPredicate(format: "baby == %@ AND kindRaw == %d AND sleepEndAt == nil",
                                    baby, CareKind.sleep.rawValue)
        req.sortDescriptors = [NSSortDescriptor(key: #keyPath(CareEvent.createdAt), ascending: false)]
        req.fetchLimit = 1
        return (try? context.fetch(req))?.first
    }

    // MARK: - 내부

    private static func newEvent(_ kind: CareKind, baby: Baby, in context: NSManagedObjectContext,
                                 at date: Date) -> CareEvent {
        let ev = CareEvent(context: context)
        ev.id = UUID()
        ev.baby = baby
        ev.kind = kind
        ev.createdAt = date
        ev.feedType = nil
        ev.diaperType = nil
        ev.lastBreastSide = nil
        return ev
    }

    private static func timeText(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

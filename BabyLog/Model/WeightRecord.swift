//
//  WeightRecord.swift
//  BabyLog
//
//  Created by 이윤오 on 2026/11/18.
//
//  몸무게 기록(성장 기록). Core Data 모델 v3 에서 추가.
//  - 하루에 한 건: 같은 날짜로 다시 입력하면 그 날 기록을 갱신한다.
//  - Baby.weightKg 는 항상 "가장 최근 날짜" 기록과 같게 유지한다 → 수유량 자동 추천이 자동 갱신.
//  ⚠️ 앱·위젯 두 타깃에 포함된다(모델에 엔티티가 있으므로 클래스도 양쪽에 필요). 앱 전용 심볼 금지.
//

import CoreData

@objc(WeightRecord)
public class WeightRecord: NSManagedObject {}

extension WeightRecord: Identifiable {}

extension WeightRecord {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<WeightRecord> {
        NSFetchRequest<WeightRecord>(entityName: "WeightRecord")
    }

    @NSManaged public var id: UUID
    @NSManaged public var measuredAt: Date
    @NSManaged public var weightKg: Double
    @NSManaged public var baby: Baby?
}

/// 성장 기록 계산 (순수 로직 — 단위 테스트 대상)
enum GrowthMath {
    /// 한 달 평균 일수 (365.25 / 12)
    static let daysPerMonth = 30.4375

    /// 생일 기준 개월수(소수). 차트 x축에 쓴다. 생일 이전 날짜는 0.
    static func ageMonths(birthday: Date, at date: Date, calendar: Calendar = .current) -> Double {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: birthday),
                                           to: calendar.startOfDay(for: date)).day ?? 0
        return max(Double(days) / daysPerMonth, 0)
    }

    /// "3개월 12일" — 만 개월 + 남은 일수
    static func ageText(birthday: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.month, .day], from: calendar.startOfDay(for: birthday),
                                        to: calendar.startOfDay(for: now))
        let m = max(c.month ?? 0, 0), d = max(c.day ?? 0, 0)
        if m == 0 { return "생후 \(d)일" }
        return d == 0 ? "\(m)개월" : "\(m)개월 \(d)일"
    }
}

/// 몸무게 기록 CRUD. 저장(save)은 호출 측에서 한다.
enum GrowthStore {
    /// 날짜 오름차순
    static func records(for baby: Baby, in context: NSManagedObjectContext) -> [WeightRecord] {
        let req: NSFetchRequest<WeightRecord> = WeightRecord.fetchRequest()
        req.predicate = NSPredicate(format: "baby == %@", baby)
        req.sortDescriptors = [NSSortDescriptor(key: #keyPath(WeightRecord.measuredAt), ascending: true)]
        return (try? context.fetch(req)) ?? []
    }

    /// 같은 날짜 기록이 있으면 갱신, 없으면 추가하고 Baby.weightKg 를 최신 기록으로 맞춘다.
    @discardableResult
    static func upsert(weightKg: Double, on date: Date, for baby: Baby,
                       in context: NSManagedObjectContext, calendar: Calendar = .current) -> WeightRecord {
        let day = calendar.startOfDay(for: date)
        let existing = records(for: baby, in: context).first { calendar.isDate($0.measuredAt, inSameDayAs: day) }
        let record = existing ?? {
            let r = WeightRecord(context: context)
            r.id = UUID()
            r.baby = baby
            return r
        }()
        record.measuredAt = day
        record.weightKg = weightKg
        syncLatestWeight(of: baby, in: context)
        return record
    }

    static func delete(_ record: WeightRecord, of baby: Baby, in context: NSManagedObjectContext) {
        context.delete(record)
        syncLatestWeight(of: baby, in: context)
    }

    /// Baby.weightKg = 가장 최근 날짜의 기록 (기록이 모두 지워지면 기존 값 유지)
    static func syncLatestWeight(of baby: Baby, in context: NSManagedObjectContext) {
        let alive = records(for: baby, in: context).filter { !$0.isDeleted }
        if let latest = alive.last { baby.weightKg = latest.weightKg }
    }

    /// 성장 기록이 생기기 전(모델 v2)에 설정에서 입력한 몸무게를 첫 기록으로 옮긴다. 변경이 있으면 true.
    @discardableResult
    static func seedIfNeeded(for baby: Baby, in context: NSManagedObjectContext) -> Bool {
        guard baby.weightKg > 0, records(for: baby, in: context).isEmpty else { return false }
        upsert(weightKg: baby.weightKg, on: Date(), for: baby, in: context)
        return true
    }
}

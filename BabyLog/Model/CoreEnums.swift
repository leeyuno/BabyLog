//
//  CoreEnums.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/11.
//

import Foundation

// ⚠️ 아래 enum 들의 rawValue(Int16)는 Core Data에 그대로 저장된다.
//    기존 값의 의미를 바꾸거나 재번호하면 저장된 데이터가 잘못 해석되므로, 추가만 할 것.

/// 기록 종류 (CareEvent.kindRaw)
enum CareKind: Int16, CaseIterable {
    case feed = 0, diaper = 1, sleep = 2
    var label: String {
        switch self {
        case .feed: return "수유"
        case .diaper: return "기저귀"
        case .sleep: return "수면"
        }
    }
}

/// 수유 종류 (CareEvent.feedTypeRaw)
enum FeedType: Int16, CaseIterable {
    case breastMilk = 0, formula = 1
    var label: String { self == .formula ? "분유" : "모유" }
}

/// 기저귀 종류 (CareEvent.diaperTypeRaw). 통계의 "배변"은 poop + mixed 만 센다.
enum DiaperType: Int16, CaseIterable {
    case pee = 0, poop = 1, mixed = 2
    var label: String {
        switch self {
        case .pee: return "소변"
        case .poop: return "대변"
        case .mixed: return "혼합"
        }
    }
}

extension CareKind {
    /// AddKind → CareKind
    init(from add: AddKind) {
        switch add {
        case .sleep:   self = .sleep
        case .feeding: self = .feed   // ✅ 이름 다름 주의
        case .diaper:  self = .diaper
        }
    }
}

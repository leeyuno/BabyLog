//
//  CoreEnums.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/11.
//

import Foundation

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

enum FeedType: Int16, CaseIterable {
    case breastMilk = 0, formula = 1
    var label: String { self == .formula ? "분유" : "모유" }
}

enum DiaperType: Int16, CaseIterable {
    case pee = 0, poop = 1, mixed = 2
    var label: String {
        switch self { case .pee: return "소변"; case .poop: return "대변"; case .mixed: return "혼합" }
    }
}


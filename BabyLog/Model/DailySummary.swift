//
//  DailySummary.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/23.
//

import Foundation

public struct DailySummary: Codable, Equatable {
    public let date: Date
    public let sleepMinutes: Double
    public let feedingML: Double
    public let diaperCount: Double
    public let avgSleepMinutes6: Double
    public let avgFeedingML6: Double
    public let avgDiaperCount6: Double
}

public enum BabyLogGroup {
    public static let appGroupId = "group.com.yourteam.BabyLog" // <- 실제 App Group ID로 교체
    public static let summaryKey = "daily_summary_v1"
}

public struct SummaryStore {
    private let ud = UserDefaults(suiteName: BabyLogGroup.appGroupId)!
    public init() {}
    public func save(_ s: DailySummary) {
        if let data = try? JSONEncoder().encode(s) { ud.set(data, forKey: BabyLogGroup.summaryKey) }
    }
    public func load() -> DailySummary? {
        guard let data = ud.data(forKey: BabyLogGroup.summaryKey) else { return nil }
        return try? JSONDecoder().decode(DailySummary.self, from: data)
    }
}

public extension DailySummary {
    static var mock: DailySummary {
        .init(date: Date(),
              sleepMinutes: 460, feedingML: 780, diaperCount: 4,
              avgSleepMinutes6: 425, avgFeedingML6: 720, avgDiaperCount6: 3.2)
    }
}

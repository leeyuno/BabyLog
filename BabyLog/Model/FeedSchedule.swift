//
//  FeedSchedule.swift
//  BabyLog
//
//  Created by 이윤오 on 2026/11/18.
//
//  다음 수유 예상 (순수 로직 + 조회). 앱·위젯 두 타깃에 포함 — 앱 전용 심볼 금지.
//
//  규칙 (Android lib/domain/feed_schedule.dart 와 동일):
//   1) 지금으로부터 48시간 안의 수유 시각만 사용
//   2) 30분 안에 이어진 수유는 한 번으로 묶는다 (모유 후 분유 보충, 양쪽 나눠 기록 등) — 묶음의 첫 시각
//   3) 최근 최대 8개 간격의 "중앙값"을 평균 간격으로 쓴다 (밤잠 같은 긴 간격 하나에 흔들리지 않게)
//   4) 묶은 수유가 3회 미만이면 예측하지 않는다
//   다음 예상 = 마지막 수유 + 중앙값 간격
//

import CoreData
import Foundation

enum FeedSchedule {
    static let window: TimeInterval = 48 * 3600
    static let mergeGap: TimeInterval = 30 * 60
    static let maxIntervals = 8
    static let minSessions = 3

    struct Prediction: Equatable {
        let lastFeed: Date
        let interval: TimeInterval
        var next: Date { lastFeed.addingTimeInterval(interval) }
    }

    /// 수유 시각들(순서 무관)로 다음 수유를 예측한다
    static func predict(feedTimes: [Date], now: Date = Date()) -> Prediction? {
        let recent = feedTimes.filter { $0 <= now && now.timeIntervalSince($0) <= window }.sorted()
        var sessions: [Date] = []
        var lastInSession: Date?
        for t in recent {
            if let prev = lastInSession, t.timeIntervalSince(prev) <= mergeGap {
                lastInSession = t   // 같은 묶음: 시작 시각은 유지
            } else {
                sessions.append(t)
                lastInSession = t
            }
        }
        guard sessions.count >= minSessions, let last = sessions.last else { return nil }
        let intervals = zip(sessions.dropFirst(), sessions).map { $0.timeIntervalSince($1) }.suffix(maxIntervals)
        return Prediction(lastFeed: last, interval: median(Array(intervals)))
    }

    static func median(_ values: [TimeInterval]) -> TimeInterval {
        let s = values.sorted()
        guard !s.isEmpty else { return 0 }
        return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
    }

    /// 해당 아기의 최근 48시간 수유 시각
    static func feedTimes(for baby: Baby, in context: NSManagedObjectContext, now: Date = Date()) -> [Date] {
        let req: NSFetchRequest<CareEvent> = CareEvent.fetchRequest()
        req.predicate = NSPredicate(format: "baby == %@ AND kindRaw == %d AND createdAt >= %@",
                                    baby, CareKind.feed.rawValue, now.addingTimeInterval(-window) as NSDate)
        req.sortDescriptors = [NSSortDescriptor(key: #keyPath(CareEvent.createdAt), ascending: true)]
        return ((try? context.fetch(req)) ?? []).map(\.createdAt)
    }

    static func prediction(for baby: Baby, in context: NSManagedObjectContext, now: Date = Date()) -> Prediction? {
        predict(feedTimes: feedTimes(for: baby, in: context, now: now), now: now)
    }

    /// "3시간 10분"
    static func intervalText(_ interval: TimeInterval) -> String {
        let m = Int((interval / 60).rounded())
        if m < 60 { return "\(m)분" }
        return m % 60 == 0 ? "\(m / 60)시간" : "\(m / 60)시간 \(m % 60)분"
    }
}

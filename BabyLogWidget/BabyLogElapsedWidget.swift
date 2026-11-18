//
//  BabyLogElapsedWidget.swift
//  BabyLogWidget
//
//  Created by 이윤오 on 2025/09/21.
//
//  "수유 경과 시간" 위젯: 마지막 수유 이후 경과 시간을 실시간 표시.
//

import WidgetKit
import SwiftUI
import CoreData

struct BabyLogElapsedEntry: TimelineEntry {
    let date: Date
    /// 마지막 수유 시각. nil 이면 기록 없음(또는 스토어 접근 불가).
    let lastFeedAt: Date?
    /// 다음 수유 예상 시각 (FeedSchedule). 수유 3회 미만이면 nil.
    var nextFeedAt: Date?
}

struct BabyLogElapsedProvider: TimelineProvider {
    func placeholder(in context: Context) -> BabyLogElapsedEntry {
        BabyLogElapsedEntry(date: Date(), lastFeedAt: Date().addingTimeInterval(-90 * 60))
    }

    func getSnapshot(in context: Context, completion: @escaping (BabyLogElapsedEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BabyLogElapsedEntry>) -> Void) {
        // 경과 시간은 Text(.relative/.timer)가 시스템에서 자동 갱신하므로
        // 1분마다 타임라인을 다시 만들 필요가 없다(위젯 갱신 예산 절약).
        // 새 기록이 저장되면 앱이 reloadAllTimelines() 를 호출한다.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [makeEntry()], policy: .after(next)))
    }

    private func makeEntry() -> BabyLogElapsedEntry {
        let next: Date? = SharedPersistence.read { ctx -> Date? in
            guard let baby = SharedPersistence.firstBaby(in: ctx) else { return nil }
            return FeedSchedule.prediction(for: baby, in: ctx)?.next
        } ?? nil
        let last: Date? = SharedPersistence.read { ctx -> Date? in
            guard let baby = SharedPersistence.firstBaby(in: ctx) else { return nil }
            let req: NSFetchRequest<CareEvent> = CareEvent.fetchRequest()
            req.predicate = NSPredicate(format: "baby == %@ AND kindRaw == %d", baby, CareKind.feed.rawValue)
            req.sortDescriptors = [NSSortDescriptor(key: #keyPath(CareEvent.createdAt), ascending: false)]
            req.fetchLimit = 1
            return (try? ctx.fetch(req))?.first?.createdAt
        } ?? nil
        return BabyLogElapsedEntry(date: Date(), lastFeedAt: last, nextFeedAt: next)
    }
}

struct BabyLogElapsedWidgetEntryView: View {
    var entry: BabyLogElapsedProvider.Entry

    var body: some View {
        VStack {
            Text("마지막 수유 이후")
                .font(.caption)
                .foregroundColor(.secondary)
            if let last = entry.lastFeedAt {
                // 시:분:초 형식으로 실시간 카운트업
                Text(last, style: .timer)
                    .font(.title3)
                    .bold()
                    .multilineTextAlignment(.center)
                    .monospacedDigit()
            } else {
                Text("기록 없음")
                    .font(.title3)
                    .bold()
            }
            if let next = entry.nextFeedAt {
                Text("다음 약 \(next.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .widgetBackground()
    }
}

struct BabyLogElapsedWidget: Widget {
    let kind: String = "BabyLogElapsedWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BabyLogElapsedProvider()) { entry in
            BabyLogElapsedWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("수유 경과 시간")
        .description("마지막 수유로부터 얼마나 지났는지 보여줍니다.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

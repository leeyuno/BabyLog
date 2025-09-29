//
//  BabyLogTodayWidget.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/21.
//

import WidgetKit
import SwiftUI
import CoreData

struct TodaySummaryEntry: TimelineEntry {
    let date: Date
    let feedCount: Int
    let feedTotalML: Int
    let sleepMinutes: Int
    let poopCount: Int
}

private let groupID = "group.com.leeyuno.babylog.ios"

struct TodaySummaryProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodaySummaryEntry {
        TodaySummaryEntry(date: .now, feedCount: 0, feedTotalML: 0, sleepMinutes: 0, poopCount: 0)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TodaySummaryEntry) -> ()) {
        completion(makeEntry())
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodaySummaryEntry>) -> ()) {
        let entry = makeEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
    
    private func makeEntry() -> TodaySummaryEntry {
        let container = sharedContainer()
        let context = container.viewContext
        
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start)!

        let babyReq: NSFetchRequest<Baby> = Baby.fetchRequest()
        babyReq.sortDescriptors =  [NSSortDescriptor(key: #keyPath(Baby.name), ascending: true)]
        guard let baby = (try? context.fetch(babyReq))?.first else {
            return TodaySummaryEntry(date: .now, feedCount: 0, feedTotalML: 0, sleepMinutes: 0, poopCount: 0)
        }

        // 수유
        let feedReq: NSFetchRequest<CareEvent> = CareEvent.fetchRequest()
        feedReq.predicate = NSPredicate(format: "baby == %@ AND kindRaw == %d AND createdAt >= %@ AND createdAt < %@",
                                        baby, CareKind.feed.rawValue, start as NSDate, end as NSDate)
        let feeds = (try? context.fetch(feedReq)) ?? []
        let feedCount = feeds.count
        let feedTotalML = feeds.reduce(0) { $0 + Int($1.feedAmountML) }

        // 배변(대변/혼합 카운트)
        let diaperReq: NSFetchRequest<CareEvent> = CareEvent.fetchRequest()
        diaperReq.predicate = NSPredicate(format: "baby == %@ AND kindRaw == %d AND createdAt >= %@ AND createdAt < %@",
                                          baby, CareKind.diaper.rawValue, start as NSDate, end as NSDate)
        let diapers = (try? context.fetch(diaperReq)) ?? []
        let poopCount = diapers.reduce(0) { acc, e in
            let isPoop = (e.diaperType == .poop || e.diaperType == .mixed)
            return acc + (isPoop ? 1 : 0)
        }

        // 수면(오늘 구간과 겹치는 분만 합산)
        let sleepReq: NSFetchRequest<CareEvent> = CareEvent.fetchRequest()
        sleepReq.predicate = NSPredicate(format: "baby == %@ AND kindRaw == %d AND createdAt >= %@ AND createdAt < %@",
                                         baby, CareKind.sleep.rawValue, start as NSDate, end as NSDate)
        let sleeps = (try? context.fetch(sleepReq)) ?? []
        let sleepMinutes = sleeps.reduce(0) { acc, e in
            guard let s = e.sleepStartAt, let fin = e.sleepEndAt /* 진행중 제외 */,
                  fin >= s else { return acc }
            // 오늘 범위와 겹치는 부분만 계산
            let overlap = overlappedMinutes(range: s...fin, today: start..<end, cal: cal)
            return acc + overlap
        }

        return TodaySummaryEntry(
            date: .now,
            feedCount: feedCount,
            feedTotalML: feedTotalML,
            sleepMinutes: sleepMinutes,
            poopCount: poopCount
        )
    }
    
    // App Group을 쓰는 NSPersistentContainer
    private func sharedContainer() -> NSPersistentContainer {
        let c = NSPersistentContainer(name: "BabyLog") // ← .xcdatamodeld 이름과 동일
        let storeURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: groupID)!
            .appendingPathComponent("BabyLog.sqlite")
        let desc = NSPersistentStoreDescription(url: storeURL)
        c.persistentStoreDescriptions = [desc]
        
        var loaded = false
        c.loadPersistentStores { _, error in
            if let error = error { print("CoreData load error:", error) }
            loaded = true
        }
        if !loaded { print("CoreData model not loaded") }
        return c
    }
    
    private func overlappedMinutes(range: ClosedRange<Date>, today: Range<Date>, cal: Calendar) -> Int {
        let start = max(range.lowerBound, today.lowerBound)
        let end = min(range.upperBound, today.upperBound.addingTimeInterval(-1))
        guard end > start else { return 0 }
        return Int(end.timeIntervalSince(start) / 60.0)
    }
}

struct TodaySummaryWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: TodaySummaryEntry
    
    var body: some View {
        switch family {
        case .accessoryRectangular:
            accessoryRectangular
        case .accessoryInline:
            Text("수유 \(entry.feedCount)회 • \(entry.feedTotalML)ml • 수면 \(entry.sleepMinutes/60)h • 배변 \(entry.poopCount)")
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 2) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 12, weight: .medium))
                    Text("\(entry.feedCount)/\(entry.poopCount)")
                        .font(.system(size: 10, weight: .semibold))
                }
            }
        default:
            systemSmall
        }
    }
    
    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("오늘 통계").font(.caption).foregroundColor(.secondary)
            HStack {
                stat(title: "수유", value: "\(entry.feedCount)회 / \(entry.feedTotalML)ml", symbol: "baby.bottle.fill")
            }
            
            HStack {
                stat(title: "수면", value: String(format: "%.1fh", Double(entry.sleepMinutes)/60.0), symbol: "moon.zzz.fill")
                stat(title: "배변", value: "\(entry.poopCount)회", symbol: "toilet.fill")
            }
        }
    }
    
    private var systemSmall: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("오늘 통계").font(.caption).foregroundColor(.secondary)
            stat(title: "수유", value: "\(entry.feedCount)회 / \(entry.feedTotalML)ml", symbol: "baby.bottle.fill")
            stat(title: "수면", value: String(format: "%.1fh", Double(entry.sleepMinutes)/60.0), symbol: "moon.zzz.fill")
            stat(title: "배변", value: "\(entry.poopCount)회", symbol: "toilet.fill")
            Spacer()
        }
        .padding()
    }
    
    private func stat(title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.caption)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.caption2).foregroundColor(.secondary)
                Text(value).font(.footnote).bold()
            }
        }
    }
}

struct BabyLogTodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BabyLogTodayWidget", provider: TodaySummaryProvider()) { entry in
            TodaySummaryWidgetView(entry: entry)
        }
        .configurationDisplayName("오늘 통계")
        .description("오늘 수유/수면/배변 요약을 보여줍니다.")
        .supportedFamilies([.systemMedium, .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

//
//  BabyLogTodayWidget.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/21.
//
//  "오늘 통계" 위젯: 오늘(자정 기준) 수유 횟수/총량, 수면 시간, 배변 횟수.
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

    static var empty: TodaySummaryEntry {
        TodaySummaryEntry(date: .now, feedCount: 0, feedTotalML: 0, sleepMinutes: 0, poopCount: 0)
    }
}

struct TodaySummaryProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodaySummaryEntry {
        .empty
    }

    func getSnapshot(in context: Context, completion: @escaping (TodaySummaryEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodaySummaryEntry>) -> Void) {
        let entry = makeEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func makeEntry() -> TodaySummaryEntry {
        SharedPersistence.read { makeEntry(in: $0) } ?? .empty
    }

    private func makeEntry(in context: NSManagedObjectContext) -> TodaySummaryEntry {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)

        guard let baby = SharedPersistence.firstBaby(in: context) else { return .empty }

        // 오늘 생성된 기록을 한 번에 조회해 메모리에서 분류 (기존: 종류별 3회 fetch)
        let events = CareStats.fetchEvents(for: baby, from: start, to: end, in: context)

        let feeds = events.filter { $0.kind == .feed }
        let poopCount = events.filter {
            $0.kind == .diaper && ($0.diaperType == .poop || $0.diaperType == .mixed)
        }.count

        // 수면: 종료된 기록 중 오늘 구간과 겹치는 분만 합산.
        // NOTE: createdAt(=종료 시각)이 오늘인 수면만 대상이라, 어제 시작·오늘 종료 수면은 오늘 부분만 포함된다.
        let sleepMinutes = events.reduce(0) { acc, e in
            guard e.kind == .sleep, let s = e.sleepStartAt, let fin = e.sleepEndAt, fin >= s else { return acc }
            return acc + overlappedMinutes(range: s...fin, today: start..<end)
        }

        return TodaySummaryEntry(
            date: .now,
            feedCount: feeds.count,
            feedTotalML: feeds.reduce(0) { $0 + Int($1.feedAmountML) },
            sleepMinutes: sleepMinutes,
            poopCount: poopCount
        )
    }

    private func overlappedMinutes(range: ClosedRange<Date>, today: Range<Date>) -> Int {
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
        content.widgetBackground()
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryRectangular:
            accessoryRectangular
        case .accessoryInline:
            Text("수유 \(entry.feedCount)회 • \(entry.feedTotalML)ml • 수면 \(sleepHoursText)h • 배변 \(entry.poopCount)")
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
            // supportedFamilies 에 systemMedium 만 있으므로 실제로는 medium 에서 이 레이아웃이 쓰인다
            systemSmall
        }
    }

    /// 수면 시간(시간 단위, 소수 첫째 자리)
    private var sleepHoursText: String {
        String(format: "%.1f", Double(entry.sleepMinutes) / 60)
    }

    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("오늘 통계").font(.caption).foregroundColor(.secondary)
            HStack {
                stat(title: "수유", value: "\(entry.feedCount)회 / \(entry.feedTotalML)ml", symbol: "baby.bottle.fill")
            }

            HStack {
                stat(title: "수면", value: "\(sleepHoursText)h", symbol: "moon.zzz.fill")
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

//
//  BabyLogDailySummaryWidget.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/23.
//

import WidgetKit
import SwiftUI

struct BabyEntry: TimelineEntry {
    let date: Date
    let summary: DailySummary?
}

struct Provider: TimelineProvider {
    let store = SummaryStore()

    func placeholder(in context: Context) -> BabyEntry {
        .init(date: .now, summary: .mock)
    }
    func getSnapshot(in context: Context, completion: @escaping (BabyEntry) -> Void) {
        completion(.init(date: .now, summary: store.load() ?? .mock))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<BabyEntry>) -> Void) {
        let entry = BabyEntry(date: .now, summary: store.load())
        // 60분마다 갱신 (원하면 조정)
        let next = Calendar.current.date(byAdding: .minute, value: 60, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct BabyLogDailySummaryWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let s = entry.summary {
            content(summary: s)
        } else {
            VStack(alignment: .leading) {
                Text("베이비로그").font(.headline)
                Text("앱을 열어 오늘 데이터를 기록하세요").font(.caption).foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    @ViewBuilder
    private func content(summary s: DailySummary) -> some View {
        // KPI 칩 3개 — WeeklyOverviewView의 MetricChipView와 동일한 표시/포맷
        VStack(alignment: .leading, spacing: 8) {
            Text("오늘 vs 6일 평균").font(.headline)
            HStack(spacing: 8) {
                DailySummaryWidgetChipView(kind: .sleep, title: "수면",
                               today: s.sleepMinutes, avg6: s.avgSleepMinutes6, unit: .timeHM)
                DailySummaryWidgetChipView(kind: .feeding, title: "수유",
                               today: s.feedingML, avg6: s.avgFeedingML6, unit: .ml)
                DailySummaryWidgetChipView(kind: .diaper, title: "배변",
                               today: s.diaperCount, avg6: s.avgDiaperCount6, unit: .count)
            }
        }
        .padding()
    }
}


struct BabyLogDailySummaryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BabyLogWidget", provider: Provider()) { entry in
            BabyLogDailySummaryWidgetEntryView(entry: entry)
        }
    }
}

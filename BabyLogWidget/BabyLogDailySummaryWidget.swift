//
//  BabyLogDailySummaryWidget.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/23.
//
//  "오늘 vs 6일 평균" 위젯. 주간 개요 화면의 KPI 칩과 같은 DailySummary 를 Core Data 에서 직접 계산한다.
//  (기존 SummaryStore(UserDefaults) 방식은 앱에서 저장하는 곳이 없어 항상 빈 상태였음)
//

import WidgetKit
import SwiftUI

struct BabyEntry: TimelineEntry {
    let date: Date
    let summary: DailySummary?
}

struct DailySummaryProvider: TimelineProvider {

    func placeholder(in context: Context) -> BabyEntry {
        .init(date: .now, summary: .mock)
    }
    func getSnapshot(in context: Context, completion: @escaping (BabyEntry) -> Void) {
        completion(.init(date: .now, summary: loadSummary() ?? .mock))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<BabyEntry>) -> Void) {
        let entry = BabyEntry(date: .now, summary: loadSummary())
        // 기록 변경은 앱이 reload 를 요청하므로, 주기 갱신은 날짜 변경 대비 정도면 충분
        let cal = Calendar.current
        let hourly = cal.date(byAdding: .minute, value: 60, to: .now) ?? .now.addingTimeInterval(3600)
        let midnight = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: .now)) ?? hourly
        completion(Timeline(entries: [entry], policy: .after(min(hourly, midnight))))
    }

    private func loadSummary() -> DailySummary? {
        SharedPersistence.read { DailySummary.make(in: $0) } ?? nil
    }
}

struct BabyLogDailySummaryWidgetEntryView: View {
    var entry: DailySummaryProvider.Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        bodyContent.widgetBackground()
    }

    @ViewBuilder
    private var bodyContent: some View {
        if let s = entry.summary {
            content(summary: s)
        } else {
            VStack(alignment: .leading) {
                Text("먹싸자").font(.headline)
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
        StaticConfiguration(kind: "BabyLogDailySummaryWidget", provider: DailySummaryProvider()) { entry in
            BabyLogDailySummaryWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("오늘 vs 6일 평균")
        .description("오늘과 오늘을 제외한 이번주 6일의 평균을 비교해서 보여줍니다.")
        // 칩 3개 레이아웃은 잠금화면(accessory*) 크기에 맞지 않아 systemMedium 만 지원
        .supportedFamilies([.systemMedium])
    }
}

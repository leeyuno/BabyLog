//
//  BabyLogNextFeedWidget.swift
//  BabyLogWidget
//
//  Created by 이윤오 on 2026/11/20.
//
//  잠금화면 "다음 수유" 위젯 — 미리 알림(할 일 목록)처럼 한 줄로 남은 시간을 보여준다 (위젯 타깃 전용).
//    직사각형: ○ 수유 / 1시간 20분 뒤 / 14:30 예정
//    한 줄:    ○ 수유 1시간 20분 뒤
//    원형:     남은 시간 링 + 1:20
//  - 남은 시간은 Text(.relative)·타이머라 시스템이 자동으로 줄여 준다 (위젯 갱신 예산 소모 없음)
//  - 예정 시각에 타임라인 항목을 하나 더 넣어 "예정 시각 지남"으로 바뀐다
//  - 기록이 바뀌면 앱이 reloadAllTimelines() 로 다시 계산 (FeedSchedule, 수유 3회 이상부터 예측)
//  - 탭하면 수유 기록 시트 (babylog://add?type=feeding)
//

import SwiftUI
import WidgetKit

struct NextFeedEntry: TimelineEntry {
    let date: Date
    /// nil 이면 예측 없음 (수유 3회 미만 / 아기 없음)
    let prediction: FeedSchedule.Prediction?

    var isOverdue: Bool { prediction.map { date >= $0.next } ?? false }
}

struct NextFeedProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextFeedEntry {
        NextFeedEntry(date: .now, prediction: .init(lastFeed: .now.addingTimeInterval(-3600), interval: 3 * 3600))
    }

    func getSnapshot(in context: Context, completion: @escaping (NextFeedEntry) -> Void) {
        completion(NextFeedEntry(date: .now, prediction: load() ?? placeholder(in: context).prediction))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextFeedEntry>) -> Void) {
        let now = Date()
        let p = load(now: now)
        var entries = [NextFeedEntry(date: now, prediction: p)]
        // 예정 시각이 되면 "예정 시각 지남"으로 바뀌도록 항목 추가
        if let p, p.next > now { entries.append(NextFeedEntry(date: p.next, prediction: p)) }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(3600))))
    }

    private func load(now: Date = Date()) -> FeedSchedule.Prediction? {
        SharedPersistence.read { ctx -> FeedSchedule.Prediction? in
            guard let baby = SharedPersistence.firstBaby(in: ctx) else { return nil }
            return FeedSchedule.prediction(for: baby, in: ctx, now: now)
        } ?? nil
    }
}

struct NextFeedWidgetView: View {
    let entry: NextFeedEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .widgetURL(DeepLink.add(.feeding))
            .widgetBackground(.clear)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline: inline
        case .accessoryCircular: circular
        default: rectangular
        }
    }

    private func time(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }

    /// ○ 수유 / 1시간 20분 뒤 / 14:30 예정
    private var rectangular: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: entry.isOverdue ? "exclamationmark.circle" : "circle")
                .font(.headline)
            VStack(alignment: .leading, spacing: 1) {
                Text("수유").font(.headline).widgetAccentable()
                if let p = entry.prediction {
                    if entry.isOverdue {
                        Text("예정 시각 지남").font(.subheadline)
                    } else {
                        (Text(p.next, style: .relative) + Text(" 뒤")).font(.subheadline)
                    }
                    Text("\(time(p.next)) 예정").font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("기록이 쌓이면 예정 시간이 나와요").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    /// ○ 수유 1시간 20분 뒤
    @ViewBuilder
    private var inline: some View {
        if let p = entry.prediction {
            if entry.isOverdue {
                Label("수유 예정 시각 지남", systemImage: "exclamationmark.circle")
            } else {
                Label {
                    Text("수유 ") + Text(p.next, style: .relative) + Text(" 뒤")
                } icon: {
                    Image(systemName: "circle")
                }
            }
        } else {
            Label("수유 기록이 더 필요해요", systemImage: "circle")
        }
    }

    /// 남은 시간 링 + 1:20
    @ViewBuilder
    private var circular: some View {
        if let p = entry.prediction, !entry.isOverdue {
            ProgressView(timerInterval: p.lastFeed...p.next, countsDown: true) {
                Image(systemName: "waterbottle.fill")
            } currentValueLabel: {
                Text(timerInterval: p.lastFeed...p.next, countsDown: true)
                    .font(.system(size: 11).monospacedDigit())
                    .multilineTextAlignment(.center)
            }
            .progressViewStyle(.circular)
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: entry.isOverdue ? "exclamationmark" : "waterbottle")
            }
        }
    }
}

struct BabyLogNextFeedWidget: Widget {
    var body: some WidgetConfiguration {
        // ⚠️ kind 문자열을 바꾸면 사용자가 추가해 둔 위젯이 사라진다
        StaticConfiguration(kind: "BabyLogNextFeedWidget", provider: NextFeedProvider()) { entry in
            NextFeedWidgetView(entry: entry)
        }
        .configurationDisplayName("다음 수유")
        .description("잠금화면에 다음 수유까지 남은 시간을 할 일처럼 보여줍니다.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

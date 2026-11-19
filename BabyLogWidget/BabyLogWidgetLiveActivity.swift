//
//  BabyLogWidgetLiveActivity.swift
//  BabyLogWidget
//
//  Created by 이윤오 on 2025/09/21.
//
//  잠금화면 · 다이나믹 아일랜드 "다음 수유" 라이브 액티비티 화면 (위젯 타깃 전용).
//  - 잠금화면: 아기 이름 · "다음 수유 약 14:30" · 남은 시간 카운트다운 · 지난 수유부터의 진행 막대
//  - 예상 시각이 지나면(isStale) "예상 시각이 지났어요"로 바뀐다
//  - 탭하면 babylog://add?type=feeding → 수유 기록 시트
//  데이터: NextFeedAttributes (앱이 NextFeedLiveActivity 로 시작·갱신)
//

import ActivityKit
import SwiftUI
import WidgetKit

struct BabyLogWidgetLiveActivity: Widget {
    /// 새벽달 아이콘과 같은 남색·달빛 색
    static let night = Color(red: 0.12, green: 0.14, blue: 0.36)
    static let moon = Color(red: 1.0, green: 0.89, blue: 0.63)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NextFeedAttributes.self) { context in
            NextFeedLockScreenView(context: context)
                .activityBackgroundTint(Self.night)
                .activitySystemActionForegroundColor(.white)
                .widgetURL(DeepLink.add(.feeding))
        } dynamicIsland: { context in
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("다음 수유", systemImage: "moon.fill").font(.caption).foregroundStyle(Self.moon)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: s.lastFeed...s.next, countsDown: true)
                        .monospacedDigit().font(.title3.weight(.semibold))
                        .frame(maxWidth: 90, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(context.attributes.babyName) · 약 \(s.next.formatted(date: .omitted, time: .shortened)) · "
                         + "평균 \(FeedSchedule.intervalText(Double(s.intervalMinutes) * 60)) 간격")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "moon.fill").foregroundStyle(Self.moon)
            } compactTrailing: {
                Text(timerInterval: s.lastFeed...s.next, countsDown: true)
                    .monospacedDigit().frame(maxWidth: 48)
            } minimal: {
                Image(systemName: "moon.fill").foregroundStyle(Self.moon)
            }
            .widgetURL(DeepLink.add(.feeding))
            .keylineTint(Self.moon)
        }
    }
}

struct NextFeedLockScreenView: View {
    let context: ActivityViewContext<NextFeedAttributes>

    var body: some View {
        let s = context.state
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "moon.stars.fill")
                .font(.title)
                .foregroundStyle(BabyLogWidgetLiveActivity.moon)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(context.attributes.babyName) 다음 수유").font(.caption).foregroundStyle(.white.opacity(0.75))
                if context.isStale {
                    Text("예상 시각이 지났어요").font(.headline).foregroundStyle(.white)
                    Text("탭해서 수유 기록").font(.caption).foregroundStyle(.white.opacity(0.75))
                } else {
                    Text("약 \(s.next.formatted(date: .omitted, time: .shortened))")
                        .font(.title2.weight(.bold)).foregroundStyle(.white)
                    ProgressView(timerInterval: s.lastFeed...s.next, countsDown: false) { EmptyView() }
                        currentValueLabel: { EmptyView() }
                        .tint(BabyLogWidgetLiveActivity.moon)
                    Text("마지막 \(s.lastFeed.formatted(date: .omitted, time: .shortened)) · "
                         + "평균 \(FeedSchedule.intervalText(Double(s.intervalMinutes) * 60)) 간격")
                        .font(.caption2).foregroundStyle(.white.opacity(0.75))
                }
            }
            Spacer(minLength: 0)
            if !context.isStale {
                Text(timerInterval: s.lastFeed...s.next, countsDown: true)
                    .font(.title.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 110, alignment: .trailing)
            }
        }
        .padding(16)
    }
}

struct BabyLogWidgetLiveActivity_Previews: PreviewProvider {
    static let attributes = NextFeedAttributes(babyName: "하늘")
    static let state = NextFeedAttributes.ContentState(lastFeed: .now.addingTimeInterval(-3600),
                                                       next: .now.addingTimeInterval(7200), intervalMinutes: 180)

    static var previews: some View {
        attributes.previewContext(state, viewKind: .content).previewDisplayName("잠금화면")
        attributes.previewContext(state, viewKind: .dynamicIsland(.compact)).previewDisplayName("아일랜드 축소")
        attributes.previewContext(state, viewKind: .dynamicIsland(.expanded)).previewDisplayName("아일랜드 확장")
    }
}

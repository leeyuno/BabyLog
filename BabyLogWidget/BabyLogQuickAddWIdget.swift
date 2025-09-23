//
//  BabyLogQuickAddWIdget.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/23.
//

import WidgetKit
import SwiftUI

struct QuickAddEntry: TimelineEntry {
    let date: Date
}

struct QuickAddProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickAddEntry {
        .init(date: .now)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (QuickAddEntry) -> ()) {
        completion(.init(date: .now))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickAddEntry>) -> Void) {
        let entry = QuickAddEntry(date: .now)
        
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct QuickAddWidgetEntryView: View {
    var entry: QuickAddProvider.Entry
    @Environment(\.widgetFamily) private var family
    
    //추가 기본 타입 설정
    private let defaultKind = "sleep"
    
    var body: some View {
        let url = URL(string: "babylog://add?type=\(defaultKind)")!
        
        switch family {
        case .systemSmall:
            Link(destination: url) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.blue)
                }
                .background(roundedBG)
            }
            .accessibilityLabel("기록 추가")
            
        default:
            Link(destination: url) {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(Color.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("기록 추가")
                            .font(.headline)
                        Text("탭하면 바로 추가 화면이 열립니다.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer(minLength: 8)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
                .background(roundedBG)
            }
            .accessibilityLabel("기록 추가")
        }
    }
    
    // iOS 17+는 containerBackground, 그 외는 background로 대체
    @ViewBuilder
    private var roundedBG: some View {
        let shape = RoundedRectangle(cornerRadius: 16)
        #if compiler(>=5.9)
        if #available(iOSApplicationExtension 17.0, *) {
            shape.fill(Color(.secondarySystemBackground))
                .containerBackground(Color.clear, for: .widget)
        } else {
            shape.fill(Color(.secondarySystemBackground))
                .background(Color.clear)
        }
        #else
        // Xcode 14 / Swift 5.7~5.8 등 구버전
        shape.fill(Color(.secondarySystemBackground))
            .background(Color.clear)
        #endif
    }
}

struct AddQuickRecoredWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AddQuickRecordWidget", provider: QuickAddProvider()) { entry in
            QuickAddWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("빠른 기록 추가")
        .description("홈 화면에서 바로 기록을 추가하세요.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

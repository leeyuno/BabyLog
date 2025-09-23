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
    private let defaultKind = "feed"
    
    var body: some View {
//        let url = URL(string: "babylog://add?type=\(defaultKind)")!
        
        switch family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            AddQuickLockWidgetView()   // 내부에서 .widgetURL 사용
        default:
            AddQuickHomeWidgetView()   // 내부에서 Link 사용
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
    
    fileprivate func makeDeepLink(_ kind: AddKind) -> URL {
        var comp = URLComponents()
        comp.scheme = "babylog"
        comp.host = "add"
        comp.queryItems = [ .init(name: "type", value: kind.rawValue) ]
        return comp.url!
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

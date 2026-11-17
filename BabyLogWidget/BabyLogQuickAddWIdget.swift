//
//  BabyLogQuickAddWIdget.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/23.
//
//  "빠른 기록 추가" 위젯. 데이터 없이 딥링크만 제공하므로 타임라인은 사실상 정적.
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

    func getSnapshot(in context: Context, completion: @escaping (QuickAddEntry) -> Void) {
        completion(.init(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickAddEntry>) -> Void) {
        // 내용이 바뀌지 않으므로 갱신 불필요
        completion(Timeline(entries: [QuickAddEntry(date: .now)], policy: .never))
    }
}

struct QuickAddWidgetEntryView: View {
    var entry: QuickAddProvider.Entry
    @Environment(\.widgetFamily) private var family

    /// 탭 시 열릴 기본 기록 종류
    private let defaultKind: AddKind = .feeding

    var body: some View {
        switch family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            AddQuickLockWidgetView(kind: defaultKind)
                .widgetBackground(.clear)
        default:
            AddQuickHomeWidgetView(kind: defaultKind)
                .widgetBackground(Color(.secondarySystemBackground))
        }
    }
}

struct AddQuickRecordWidget: Widget {
    var body: some WidgetConfiguration {
        // ⚠️ kind 문자열을 바꾸면 사용자가 추가해 둔 위젯이 사라진다
        StaticConfiguration(kind: "AddQuickRecordWidget", provider: QuickAddProvider()) { entry in
            QuickAddWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("빠른 기록 추가")
        .description("홈 화면에서 바로 기록을 추가하세요.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

// MARK: - 위젯 공용 배경

extension View {
    /// iOS 17+ 에서는 containerBackground 가 필수(미적용 시 "Please adopt containerBackground API" 표시).
    /// iOS 16 에서는 아무것도 하지 않는다 — 홈 위젯은 WidgetBackground 색상 에셋이 기본 배경이고,
    /// 잠금화면(accessory*)에 배경을 그리면 불투명 박스가 생기기 때문.
    @ViewBuilder
    func widgetBackground(_ color: Color = Color(.systemBackground)) -> some View {
        #if compiler(>=5.9)
        if #available(iOS 17.0, *) {
            self.containerBackground(color, for: .widget)
        } else {
            self
        }
        #else
        self
        #endif
    }
}

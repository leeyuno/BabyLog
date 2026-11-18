//
//  EventRowView.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/11.
//
//  타임라인의 기록 1행. 종류별 아이콘/제목/부가정보 + 기록 시각.
//

import SwiftUI
import CoreData

struct EventRowView: View {
    let event: CareEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName).font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
            Text(event.createdAt, style: .time)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch event.kind {
        case .feed: return "baby.bottle.fill"
        case .diaper: return "toilet.fill"
        case .sleep: return "moon.zzz.fill"
        }
    }

    private var title: String {
        switch event.kind {
        case .feed:
            if event.isDirectBreastfeeding { return "수유 (모유 직접)" }
            let t = event.feedType?.label ?? "-"
            return "수유 (\(t))"
        case .diaper:
            return "기저귀 (\(event.diaperType?.label ?? "-"))"
        case .sleep:
            return "수면"
        }
    }

    private var subtitle: String {
        switch event.kind {
        case .feed:
            if event.isDirectBreastfeeding {
                return Self.breastSummary(left: Int(event.breastLeftSec), right: Int(event.breastRightSec),
                                          last: event.lastBreastSide)
            }
            let amount = event.feedAmountML > 0 ? "\(event.feedAmountML) ml" : "-"
            return "수유량 \(amount)"
        case .diaper:
            return event.note ?? "기록됨"
        case .sleep:
            if let m = event.sleepDurationMinutes {
                return "총 \(m)분 수면"
            } else if let s = event.sleepStartAt {
                return "시작 \(s.formatted(date: .omitted, time: .shortened))"
            } else {
                return "수면 기록"
            }
        }
    }

    /// "왼 8분 · 오 12분 (총 20분) · 오른쪽에서 끝" — 시간이 없으면 "시간 기록 없음"
    static func breastSummary(left: Int, right: Int, last: BreastSide?) -> String {
        let total = left + right
        guard total > 0 else { return "시간 기록 없음" }
        func m(_ s: Int) -> Int { Int((Double(s) / 60).rounded()) }
        var text = "왼 \(m(left))분 · 오 \(m(right))분 (총 \(m(total))분)"
        if let last { text += " · \(last.label)에서 끝" }
        return text
    }
}

struct EventRowView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PreviewPersistence.controller.container.viewContext

        // 미리보기용 fetch
        let request: NSFetchRequest<CareEvent> = CareEvent.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CareEvent.createdAt, ascending: false)]
        request.fetchLimit = 1

        let event = (try? context.fetch(request).first) ?? {
            let e = CareEvent(context: context)
            e.id = UUID()
            e.kind = .feed
            e.feedType = .formula
            e.feedAmountML = 120
            e.createdAt = Date()
            return e
        }()

        return EventRowView(event: event)
            .previewLayout(.sizeThatFits)
            .padding()
    }
}

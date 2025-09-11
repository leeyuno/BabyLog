//
//  EventRowView.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/11.
//

import SwiftUI

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
}

struct EventRowView_Previews: PreviewProvider {
    static var previews: some View {
        EventRowView(event: CareEvent(entity: <#T##NSEntityDescription#>, insertInto: <#T##NSManagedObjectContext?#>))
    }
}

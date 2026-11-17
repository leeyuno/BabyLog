//
//  FallbackBars.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/21.
//
//  ⚠️ 현재 미사용. (iOS 16 미만용 Charts 대체 막대 — 최소 배포 타깃이 16.0 이므로 삭제 후보)
//

import SwiftUI

struct FallbackBars: View {
    let title: String
    let days: [Date]
    let values: [DoubleConvertible]

    init(title: String, days: [Date], values: [Int]) {
        self.title = title
        self.days = days
        self.values = values.map { .double(Double($0)) }
    }

    init(title: String, days: [Date], values: [Double]) {
        self.title = title
        self.days = days
        self.values = values.map { .double($0) }
    }

    var body: some View {
        let maxV: Double = max(values.map { $0.asDouble }.max() ?? 0.0, 1.0)

        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(values.enumerated()), id: \.offset) { idx, v in
                    VStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.accentColor.opacity(0.8))
                            .frame(width: 16, height: CGFloat(v.asDouble / maxV) * 120)
                        Text(days[idx], format: .dateTime.weekday(.abbreviated))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 150)
        }
    }

    enum DoubleConvertible {
        case double(Double)
        var asDouble: Double {
            switch self {
            case let .double(d):
                return d
            }
        }
    }
}

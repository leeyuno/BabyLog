//
//  DailySummaryWidgetChipView.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/23.
//

import SwiftUI

struct DailySummaryWidgetChipView: View {
    enum Kind { case sleep, feeding, diaper }
    enum Unit { case timeHM, ml, count }

    let kind: Kind
    let title: String
    /// today/avg6 단위:
    /// - timeHM: 분(min)
    /// - ml: ml
    /// - count: 회
    let today: Double
    let avg6: Double
    let unit: Unit

    private var iconName: String {
        switch kind {
        case .sleep: return "moon.zzz.fill"
        case .feeding: return "drop.fill"       // 또는 "baby.bottle.fill"
        case .diaper: return "toilet.fill"
        }
    }
    private var iconColor: Color {
        switch kind {
        case .sleep: return Color.indigo
        case .feeding: return Color.blue
        case .diaper: return Color.orange
        }
    }
    private var delta: Double { today - avg6 }
    private var deltaText: String {
        if abs(delta) < 0.001 { return "—" }
        return "\(delta >= 0 ? "▲" : "▼") \(format(abs(delta)))"
    }
    private var deltaColor: Color {
        abs(delta) < 0.001 ? .secondary : (delta >= 0 ? .green : .red)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: iconName).foregroundStyle(iconColor)
                Text(title).font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Text(deltaText)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(deltaColor)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)  // 말줄임 방지
                    .layoutPriority(1)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(format(today))
                    .font(.subheadline)            // 위젯 공간 고려해 title3 대신 약간 줄임
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text("6일 평균 \(format(avg6))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel("\(title), 오늘 \(format(today)), 최근 6일 평균 \(format(avg6)), 차이 \(deltaText)")
    }

    private func format(_ v: Double) -> String {
        switch unit {
        case .timeHM:
            let m = Int((v).rounded()) // 분
            return String(format: "%d:%02d", m/60, m%60)
        case .ml:
            return "\(Int(v.rounded())) ml"
        case .count:
            return v.rounded() == v ? "\(Int(v))회" : String(format: "%.1f회", v)
        }
    }
}

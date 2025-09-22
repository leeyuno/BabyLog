//
//  MetricChipView.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/22.
//

import SwiftUI
import CoreData

// MARK: - 패턴 #1 칩 컴포넌트 (SwiftUI)
struct MetricChipView: View {
    enum Kind { case sleep, feeding, diaper }
    enum Unit { case timeHM, ml, count }
    
    let kind: Kind
    let title: String
    /// today/avg6 단위:
    /// - timeHM: 분(minute)
    /// - ml: ml
    /// - count: 횟수
    let today: Double
    let avg6: Double
    let unit: Unit
    
    var iconName: String {
        switch kind {
        case .sleep: return "moon.zzz.fill"
        case .feeding: return "drop.fill" // 또는 "baby.bottle.fill"
        case .diaper: return "toilet.fill"
        }
    }
    var iconColor: Color {
        switch kind {
        case .sleep: return .indigo
        case .feeding: return .blue
        case .diaper: return .orange
        }
    }
    var delta: Double { today - avg6 }
    var deltaText: String {
        if abs(delta) < 0.001 { return "—" }
        return "\(delta >= 0 ? "▲" : "▼") \(format(abs(delta)))"
    }
    var deltaColor: Color {
        abs(delta) < 0.001 ? .secondary : (delta >= 0 ? .green : .red)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: iconName).foregroundStyle(iconColor)
                Text(title).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(deltaText)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(deltaColor)
                    .lineLimit(1)                // 한 줄로 제한
                    .fixedSize(horizontal: true, vertical: false) // 가로 길이만큼 확장
                    .layoutPriority(1)           // 다른 뷰보다 우선 배치
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(format(today)).font(.title3).fontWeight(.semibold)
                Text("6일 평균 \(format(avg6))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel("\(title), 오늘 \(format(today)), 최근 6일 평균 \(format(avg6)), 차이 \(deltaText)")
    }
    
    func format(_ v: Double) -> String {
        switch unit {
        case .timeHM:
            let m = Int((v).rounded()) // 분단위
            return String(format: "%d:%02d", m/60, m%60)
        case .ml:
            return "\(Int(v.rounded())) ml"
        case .count:
            return v.rounded() == v ? "\(Int(v))회" : String(format: "%.1f회", v)
        }
    }
}

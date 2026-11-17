//
//  ChartsGroupedBars.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/21.
//

import SwiftUI
import Charts

/// 일별 수유(ml)/수면(h)/배변(회)을 날짜별 그룹 막대로 표시.
/// ⚠️ 세 지표의 단위가 달라 같은 y축에서 수유(수백 ml)가 다른 값을 압도한다 — 개선 후보.
struct ChartsGroupedBars: View {
    let totals: [DayTotals]

    private var rows: [SeriesRow] {
        let df = DateFormatter()
        df.dateFormat = "M/d"
        return totals.flatMap { d -> [SeriesRow] in
            let label = df.string(from: d.day)
            return [
                SeriesRow(id: "\(label)-feed", dayLabel: label, metric: "수유(ml)", value: Double(d.feedML)),
                SeriesRow(id: "\(label)-sleep", dayLabel: label, metric: "수면(h)", value: d.sleepHours),
                SeriesRow(id: "\(label)-poop", dayLabel: label, metric: "배변(회)", value: Double(d.poopCount))
            ]
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("최근 7일 비교").font(.headline)
            Chart(rows) {
                BarMark(x: .value("날짜", $0.dayLabel), y: .value("값", $0.value))
                    .position(by: .value("지표", $0.metric))
            }
            .chartLegend(position: .bottom)
            .frame(height: 280)
        }
    }

    /// 안정적인 id(날짜+지표) — 매 렌더마다 UUID 를 새로 만들면 차트가 전체 재생성된다.
    struct SeriesRow: Identifiable {
        let id: String
        let dayLabel: String
        let metric: String
        let value: Double
    }
}

//
//  ChartsGroupedBars.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/21.
//

import SwiftUI
import Charts

@available(iOS 16.0, *)
struct ChartsGroupedBars: View {
    let days: [Date]
    let data: [(date: Date, feedML: Int, sleepHours: Double, poopCount: Int)]
    
    private var rows: [SeriesRow] {
        let df = DateFormatter()
        df.dateFormat = "M/d"
        return data.flatMap { d -> [SeriesRow] in
            let label = df.string(from: d.date)
            return [
                SeriesRow(day: d.date, dayLabel: label, metric: "수유(ml)", value: Double(d.feedML)),
                SeriesRow(day: d.date, dayLabel: label, metric: "수면(h)", value: d.sleepHours),
                SeriesRow(day: d.date, dayLabel: label, metric: "배변(회)", value: Double(d.poopCount))
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
    
    struct SeriesRow: Identifiable {
        var id = UUID()
        let day: Date
        let dayLabel: String
        let metric: String
        let value: Double
    }
}

//
//  WeeklyMetricChart.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/21.
//
//  주간 개요의 "최근 7일" 막대 차트. [수유 | 수면 | 배변] 중 하나를 골라 지표마다 자기 축으로 그린다.
//  (예전에는 세 지표를 한 y축에 그려 수유 ml 가 수면·배변 막대를 묻어 버렸다.) Android weekly_overview_page 와 같은 방식.
//  - 오늘 막대는 진하게, 나머지는 옅게. 막대 위에 값 표시.
//

import Charts
import SwiftUI

struct WeeklyMetricChart: View {
    let totals: [DayTotals]
    @State private var metric: Metric = .feed

    enum Metric: String, CaseIterable, Identifiable {
        case feed = "수유", sleep = "수면", poop = "배변"
        var id: Self { self }

        /// MetricChipView 의 아이콘 색과 맞춘다
        var color: Color {
            switch self {
            case .feed: return .blue
            case .sleep: return .indigo
            case .poop: return .orange
            }
        }

        func value(_ day: DayTotals) -> Double {
            switch self {
            case .feed: return Double(day.feedML)
            case .sleep: return day.sleepHours
            case .poop: return Double(day.poopCount)
            }
        }

        func label(_ value: Double) -> String {
            switch self {
            case .feed: return "\(Int(value))"
            case .sleep: return String(format: "%.1f", value)
            case .poop: return "\(Int(value))"
            }
        }

        var unit: String {
            switch self {
            case .feed: return "ml"
            case .sleep: return "시간"
            case .poop: return "회"
            }
        }
    }

    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("최근 7일").font(.headline)
                Spacer()
                Text("단위: \(metric.unit)").font(.caption).foregroundStyle(.secondary)
            }
            Picker("지표", selection: $metric) {
                ForEach(Metric.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            chart
        }
    }

    private var chart: some View {
        Chart(totals, id: \.day) { day in
            let value = metric.value(day)
            BarMark(
                x: .value("날짜", day.day, unit: .day),
                y: .value(metric.rawValue, value)
            )
            .foregroundStyle(metric.color.opacity(Calendar.current.isDate(day.day, inSameDayAs: today) ? 1 : 0.45))
            .cornerRadius(4)
            .annotation(position: .top) {
                Text(metric.label(value))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.month(.defaultDigits).day(), centered: true)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: metric)
        .frame(height: 220)
    }
}

//
//  GrowthChartView.swift
//  BabyLog
//
//  Created by 이윤오 on 2026/11/18.
//
//  성장 탭의 몸무게 차트.
//  - 아기 몸무게: 진한 선 + 점
//  - 성별·생일이 있고 0~24개월이면 WHO 성장 표준을 뒤에 깐다
//      바깥 음영 = 3~97 백분위, 안쪽 음영 = 15~85 백분위, 점선 = 50(중앙값)
//  - 생일이 없으면 날짜 축으로 아기 선만 그린다
//

import Charts
import CoreData
import SwiftUI

struct GrowthChartPoint: Identifiable {
    let id: NSManagedObjectID
    let x: Double        // 개월수 (생일 기준)
    let date: Date
    let kg: Double
}

struct GrowthChartView: View {
    let points: [GrowthChartPoint]
    let byAge: Bool
    let sex: BabySex

    private struct Band: Identifiable {
        let x: Double
        let p3: Double, p15: Double, p50: Double, p85: Double, p97: Double
        var id: Double { x }
    }

    /// WHO 곡선을 그릴 수 있는지 (생일·성별이 있고 기록이 24개월 이하)
    private var showsWHO: Bool {
        byAge && sex != .unknown && (points.map(\.x).max() ?? 0) <= WHOGrowth.maxMonths
    }

    /// x 범위: 0 ~ (마지막 기록 + 1개월, 최소 3개월, 최대 24개월)
    private var maxX: Double {
        min(max(((points.map(\.x).max() ?? 0) + 1).rounded(.up), 3), WHOGrowth.maxMonths)
    }

    private var bands: [Band] {
        guard showsWHO else { return [] }
        return stride(from: 0.0, through: maxX, by: 0.25).compactMap { x in
            guard let lms = WHOGrowth.lms(sex: sex, months: x) else { return nil }
            let w = { (z: Double) in WHOGrowth.weight(z: z, lms: lms) }
            let z = WHOGrowth.curves.map(\.z)
            return Band(x: x, p3: w(z[0]), p15: w(z[1]), p50: w(z[2]), p85: w(z[3]), p97: w(z[4]))
        }
    }

    var body: some View {
        let bands = self.bands
        let values = points.map(\.kg) + bands.flatMap { [$0.p3, $0.p97] }
        let lo = max((values.min() ?? 0) - 0.3, 0), hi = (values.max() ?? 1) + 0.3
        let tint = Color.accentColor

        Chart {
            ForEach(bands) { b in
                AreaMark(x: .value("개월", b.x), yStart: .value("3", b.p3), yEnd: .value("97", b.p97),
                         series: .value("구간", "3-97"))
                    .foregroundStyle(tint.opacity(0.08))
                AreaMark(x: .value("개월", b.x), yStart: .value("15", b.p15), yEnd: .value("85", b.p85),
                         series: .value("구간", "15-85"))
                    .foregroundStyle(tint.opacity(0.14))
                LineMark(x: .value("개월", b.x), y: .value("kg", b.p50), series: .value("선", "WHO 50"))
                    .foregroundStyle(Color.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
            ForEach(points) { p in
                if byAge {
                    LineMark(x: .value("개월", p.x), y: .value("kg", p.kg), series: .value("선", "아기"))
                        .foregroundStyle(tint)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("개월", p.x), y: .value("kg", p.kg))
                        .foregroundStyle(tint)
                } else {
                    LineMark(x: .value("날짜", p.date), y: .value("kg", p.kg))
                        .foregroundStyle(tint)
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("날짜", p.date), y: .value("kg", p.kg))
                        .foregroundStyle(tint)
                }
            }
        }
        .chartYScale(domain: lo...hi)
        .chartYAxisLabel("kg")
        .chartXAxisLabel(byAge ? "개월" : "")
        .modifier(AgeAxis(enabled: byAge, maxX: maxX))
    }

    /// 개월 축은 0 ~ maxX 로 고정
    private struct AgeAxis: ViewModifier {
        let enabled: Bool
        let maxX: Double
        func body(content: Content) -> some View {
            if enabled { content.chartXScale(domain: 0...maxX) } else { content }
        }
    }
}

/// 최신 기록의 WHO 백분위 안내 (성별·생일 필요, 0~24개월)
struct WHOPercentileNote: View {
    let latest: GrowthChartPoint?
    let byAge: Bool
    let sex: BabySex

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if sex == .unknown {
                Text("설정에서 성별을 입력하면 WHO 성장곡선과 비교할 수 있어요.")
            } else if let p = latest, byAge,
                      let pct = WHOGrowth.percentile(weight: p.kg, sex: sex, months: p.x) {
                Text("WHO 기준 백분위 \(Self.format(pct)) · 같은 개월수 \(sex.label) 100명 중 약 \(Int(pct.rounded()))명보다 무거워요")
                    .foregroundStyle(.primary)
                Text("음영은 WHO 성장 표준 3~97 · 15~85 백분위, 점선은 중앙값이에요. 진단이 아닌 참고용입니다.")
            } else if latest != nil, byAge {
                Text("WHO 비교는 24개월까지만 제공돼요.")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    static func format(_ pct: Double) -> String {
        if pct < 1 { return "1 미만" }
        if pct > 99 { return "99 초과" }
        return "\(Int(pct.rounded()))"
    }
}

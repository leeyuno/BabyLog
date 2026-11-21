//
//  WeeklyOverviewView.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/21.
//
//  최근 7일 요약: 합계 pill / 일별 그룹 막대 차트 / 오늘 vs 6일 평균 칩.
//  집계는 CareStats.aggregate (DailySummary.swift) — 위젯과 동일 규칙.
//

import SwiftUI
import CoreData

struct WeeklyOverviewView: View {

    let baby: Baby

    @Environment(\.managedObjectContext) private var context

    @FetchRequest private var events: FetchedResults<CareEvent>

    /// 최근 7일(오늘 포함) startOfDay, 오름차순. init 시점 기준으로 고정.
    private let days: [Date]

    init(baby: Baby) {
        self.baby = baby

        let cal = Calendar.current
        let days = CareStats.recentDays(7)
        self.days = days
        let start = days.first ?? cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())) ?? Date()

        // 해당 기간 이벤트만 가져오기 — 집계 규칙은 CareStats(위젯과 공용)
        _events = FetchRequest<CareEvent>(
            fetchRequest: {
                let req: NSFetchRequest<CareEvent> = CareEvent.fetchRequest()
                req.sortDescriptors = [NSSortDescriptor(key: #keyPath(CareEvent.createdAt), ascending: true)]
                req.predicate = NSPredicate(format: "baby == %@ AND createdAt >= %@ AND createdAt < %@",
                                            baby, start as NSDate, end as NSDate)
                return req
            }(),
            animation: .default
        )
    }

    var body: some View {
        // body 평가당 한 번만 집계 (기존: 섹션마다 중복 집계)
        let totals = CareStats.aggregate(events: Array(events), days: days)

        return ScrollView {
            VStack(spacing: 24) {
                headerTotals(totals)
                WeeklyMetricChart(totals: totals)
                kpiChips(DailySummary(totals: totals))
            }
            .padding()
        }
        .navigationTitle("주간 개요")
    }

    private func headerTotals(_ totals: [DayTotals]) -> some View {
        let feedSum = totals.reduce(0) { $0 + $1.feedML }
        let sleepSumHours = totals.reduce(0.0) { $0 + $1.sleepHours }
        let poopCount = totals.reduce(0) { $0 + $1.poopCount }

        return VStack(alignment: .leading, spacing: 12) {
            Text(formattedRange())
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                StatPill(title: "수유", value: "\(feedSum) ml", systemImage: "baby.bottle.fill")
                StatPill(title: "수면", value: String(format: "%.1f h", sleepSumHours), systemImage: "moon.zzz.fill")
                StatPill(title: "배변", value: "\(poopCount) 회", systemImage: "toilet.fill")
            }
        }
    }

    /// 오늘 vs 직전 6일 평균 (홈 위젯 "오늘 vs 6일 평균"과 같은 DailySummary 사용)
    private func kpiChips(_ s: DailySummary) -> some View {
        HStack(spacing: 8) {
            MetricChipView(kind: .sleep, title: "수면",
                           today: s.sleepMinutes, avg6: s.avgSleepMinutes6, unit: .timeHM)
            MetricChipView(kind: .feeding, title: "수유",
                           today: s.feedingML, avg6: s.avgFeedingML6, unit: .ml)
            MetricChipView(kind: .diaper, title: "배변",
                           today: s.diaperCount, avg6: s.avgDiaperCount6, unit: .count)
        }
        .frame(height: 80)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("오늘 요약과 최근 6일 평균")
    }

    private func formattedRange() -> String {
        guard let first = days.first, let last = days.last else { return "" }
        let f = DateFormatter()
        f.dateFormat = "M.d"
        return "\(f.string(from: first)) - \(f.string(from: last))"
    }

    private struct StatPill: View {
        let title: String
        let value: String
        let systemImage: String

        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.caption).foregroundColor(.secondary)
                    Text(value).font(.headline)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
        }
    }
}

struct WeeklyOverviewView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PreviewPersistence.controller.container.viewContext

        let request: NSFetchRequest<Baby> = Baby.fetchRequest()
        let baby = (try? context.fetch(request).first) ?? {
            let b = Baby(context: context)
            b.id = UUID()
            b.name = "Preview Baby"
            b.birthday = Date()
            return b
        }()

        WeeklyOverviewView(baby: baby)
            .environment(\.managedObjectContext, context)
            .preferredColorScheme(.light)

        WeeklyOverviewView(baby: baby)
            .environment(\.managedObjectContext, context)
            .preferredColorScheme(.dark)
    }
}

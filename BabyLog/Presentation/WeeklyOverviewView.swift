//
//  WeeklyOverviewView.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/21.
//

import SwiftUI
import CoreData

struct WeeklyOverviewView: View {
    
    let baby: Baby
    
    @Environment(\.managedObjectContext) private var context
    
    @FetchRequest private var events: FetchedResults<CareEvent>
    
    private let days: [Date]  // 최근 7일 (오늘 포함)
    
    init(baby: Baby) {
        self.baby = baby
        
        let cal = Calendar.current
        let endOfToday = cal.date(bySettingHour: 23, minute: 59, second: 59, of: Date()) ?? Date()
        let start = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: Date())) ?? Date().addingTimeInterval(-6*86400)
        
        var tmp: [Date] = []
        for i in 0..<7 {
            if let d = cal.date(byAdding: .day, value: i, to: cal.startOfDay(for: start)) {
                tmp.append(d)
            }
        }
        self.days = tmp
        
        // 해당 기간 이벤트만 가져오기
        let pred = NSPredicate(format: "baby == %@ AND createdAt >= %@ AND createdAt <= %@",
                               baby, start as NSDate, endOfToday as NSDate)
        
        _events = FetchRequest<CareEvent>(
            fetchRequest: {
                let req = NSFetchRequest<CareEvent>(entityName: "CareEvent")
                req.sortDescriptors = [NSSortDescriptor(key: #keyPath(CareEvent.createdAt), ascending: true)]
                req.predicate = pred
                return req
            }(),
            animation: .default
        )
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerTotals
                
                if #available(iOS 16.0, *) {
                    ChartsGroupedBars(days: days, data: aggregateByDay(days: days, events: Array(events)))
                } else {
                    
                }
            }
            .padding()
        }
        .navigationTitle("주간 개요")
    }
    
    private var headerTotals: some View {
        let feedSum = aggregateFeedMLByDay(days: days, events: Array(events)).reduce(0, +)
        let sleepSumHours = aggregateSleepHoursByDay(days: days, events: Array(events)).reduce(0.0, +)
        let poopCount = aggregatePoopCountByDay(days: days, events: Array(events)).reduce(0, +)
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("\(formattedRange())")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                StatPill(title: "수유", value: "\(feedSum) ml", systemImage: "baby.bottle.fill")
                StatPill(title: "수면", value: String(format: "%1f h", sleepSumHours), systemImage: "moon.zzz.fill")
                StatPill(title: "배변", value: "\(poopCount) 회", systemImage: "toilet.fill")
            }
        }
    }
    
    private func formattedRange() -> String {
        let f = DateFormatter()
        f.dateFormat = "M.d"
        guard let first = days.first, let last = days.last else { return "" }
        return "\(f.string(from: first)) - \(f.string(from: last))"
    }
    
    private func aggregateByDay(days: [Date], events: [CareEvent]) -> [(date: Date, feedML: Int, sleepHours: Double, poopCount: Int)] {
        let cal = Calendar.current
        var map: [Date: (Int, Double, Int)] = [:]
        
        for dayStart in days {
            map[dayStart] = (0, 0.0, 0)
        }
        
        for e in events {
            let dayKey = cal.startOfDay(for: e.createdAt)
            guard map[dayKey] != nil else { continue }
            
            switch e.kind {
            case .feed:
                let ml = Int(e.feedAmountML)
                let curr = map[dayKey]!
                map[dayKey] = (curr.0 + ml, curr.1, curr.2)
            case .diaper:
                let isPoop = (e.diaperType == .poop || e.diaperType == .mixed)
                let curr = map[dayKey]!
                map[dayKey] = (curr.0, curr.1, curr.2 + (isPoop ? 1 : 0))
            case .sleep:
                if let start = e.sleepStartAt, let end = e.sleepEndAt, end > start {
                    let minutes = end.timeIntervalSince(start) / 60.0
                    let hours = minutes / 60.0
                    let curr = map[dayKey]!
                    map[dayKey] = (curr.0, curr.1 + hours, curr.2)
                }
            }
        }
        
        return days.map { d in
            let v = map[d] ?? (0, 0.0, 0)
            return (d, v.0, v.1, v.2)
        }
    }
    
    private func aggregateFeedMLByDay(days: [Date], events: [CareEvent]) -> [Int] {
        aggregateByDay(days: days, events: events).map { $0.feedML }
    }
    
    private func aggregateSleepHoursByDay(days: [Date], events: [CareEvent]) -> [Double] {
        aggregateByDay(days: days, events: events).map { $0.sleepHours }
    }
    
    private func aggregatePoopCountByDay(days: [Date], events: [CareEvent]) -> [Int] {
        aggregateByDay(days: days, events: events).map { $0.poopCount }
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
    }
}

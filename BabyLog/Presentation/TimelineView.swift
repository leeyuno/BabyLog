//
//  TimelineView.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/11.
//

import SwiftUI
import CoreData

struct TimelineView: View {
    let baby: Baby
    @Environment(\.managedObjectContext) private var context
    @State private var showAddSheet = false
    
    @FetchRequest private var events: FetchedResults<CareEvent>

    init(baby: Baby) {
        self.baby = baby
        let since = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date().addingTimeInterval(-86400)
        let predicate = NSPredicate(format: "baby == %@ AND createAy >= %@", baby, since as NSDate)
        _events = FetchRequest<CareEvent>(
            sortDescriptors: [NSSortDescriptor(keyPath: \CareEvent.createdAt, ascending: false)],
            predicate: predicate,
            animation: .default
        )
    }
    
    var body: some View {
        NavigationStack {
            List {
                if events.isEmpty {
                    ContentUnavailableView("기록 없음", systemImage: "calendar.badge.exclamationmark", description: Text("오른쪽 위 + 버튼으로 첫 기록을 추가하세요."))
                } else {
                    ForEach(events) { ev in
                        EventRowView(event: ev)
                    }
                    .onDelete(perform: delete)
                }
            }
            .navigationTitle("\(baby.name) 타임라인")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                
            }
        }
    }
    
    private func delete(_ offsets: IndexSet) {
            offsets.map { events[$0] }.forEach(context.delete)
            try? context.save()
        }
}

struct TimelineView_Previews: PreviewProvider {
    static var previews: some View {
        TimelineView()
    }
}

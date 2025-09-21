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
    
    @State private var editingEvent: CareEvent? = nil

    init(baby: Baby) {
        self.baby = baby
        let since = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date().addingTimeInterval(-86400)
        let predicate = NSPredicate(format: "baby == %@ AND createdAt >= %@", baby, since as NSDate)
        _events = FetchRequest<CareEvent>(
            entity: CareEvent.entity(),
            sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)],
            predicate: predicate,
            animation: .default
        )
    }
    
    var body: some View {
        NavigationStack {
            List {
                if events.isEmpty {
                    EmptyStateView(
                        title: "기록 없음",
                        systemImage: "calendar.badge.exclamationmark",
                        message: "오른쪽 위 + 버튼으로 첫 기록을 추가하세요."
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(events) { ev in
                        EventRowView(event: ev)
                            .swipeActions(edge: .trailing) {
                                Button {
                                    editingEvent = ev
                                } label: {
                                    Label("편집", systemImage: "pencil")
                                }
                            }
                    }
                    .onDelete(perform: delete)
                }
            }
            .navigationTitle("\(baby.name) 타임라인")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddEventView(baby: baby)
            }
            .sheet(item: $editingEvent) { ev in
                EditEventTimeView(event: ev)
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
        let context = PreviewPersistence.controller.container.viewContext
        
        let request: NSFetchRequest<Baby> = Baby.fetchRequest()
        let baby = (try? context.fetch(request).first) ?? {
            let b = Baby(context: context)
            b.id = UUID()
            b.name = "Preview Baby"
            b.birthday = Date()
            return b
        }()
        
        TimelineView(baby: baby)
    }
}

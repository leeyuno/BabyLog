//
//  EditEventTimeView.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/17.
//

import SwiftUI
import CoreData

struct EditEventTimeView: View {
    @ObservedObject var event: CareEvent
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    // 로컬 편집용 상태
    @State private var createdAt: Date
    @State private var sleepStart: Date
    @State private var sleepEnd: Date
    @State private var isOngoingSleep: Bool
    
    init(event: CareEvent) {
        self.event = event
        
        _createdAt = State(initialValue: event.createdAt)
        
        let start = event.sleepStartAt ?? event.createdAt
        _sleepStart = State(initialValue: start)
        
        if let end = event.sleepEndAt {
            _sleepEnd = State(initialValue: end)
            _isOngoingSleep = State(initialValue: false)
        } else {
            _sleepEnd = State(initialValue: Date())
            _isOngoingSleep = State(initialValue: true)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                switch event.kind {
                case .feed, .diaper:
                    Section(header: Text("기록 시간")) {
                        DatePicker("시간", selection: $createdAt, displayedComponents: [.hourAndMinute])
                            .datePickerStyle(.wheel)
                    }
                case .sleep:
                    Section(header: Text("수면 시간")) {
                        DatePicker("시간", selection: $sleepStart, displayedComponents: [.hourAndMinute])
                            .datePickerStyle(.wheel)
                        Toggle("진행중", isOn: $isOngoingSleep)
                        if !isOngoingSleep {
                            DatePicker("종료", selection: $sleepEnd, displayedComponents: [.hourAndMinute])
                                .datePickerStyle(.wheel)
                        }
                    }
                }
            }
            .navigationTitle("시간 편집")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장") { save() }
                        .disabled(!isValid)
                }
            }
            .onAppear(perform: loadInitial)
        }
    }
    
    private func loadInitial() {
        switch event.kind {
        case .feed, .diaper:
            createdAt = event.createdAt
        case .sleep:
            sleepStart = event.sleepStartAt ?? event.createdAt
            if let end = event.sleepEndAt {
                sleepEnd = end
                isOngoingSleep = false
            } else {
                sleepEnd = Date()
                isOngoingSleep = true
            }
        }
    }
    
    private var isValid: Bool {
        switch event.kind {
        case .feed, .diaper:
            return true
        case .sleep:
            return isOngoingSleep || sleepEnd >= sleepStart
        }
    }
    
    private func save() {
        switch event.kind {
        case .feed, .diaper:
            event.createdAt = createdAt
        case .sleep:
            event.sleepStartAt = sleepStart
            event.sleepEndAt = isOngoingSleep ? nil : sleepEnd
            
            if !isOngoingSleep, let end = event.sleepEndAt {
                event.createdAt = end
            } else {
                event.createdAt = sleepStart
            }
        }
        
        do {
            try context.save()
            dismiss()
        } catch {
            print("Save error: \(error.localizedDescription)")
        }
    }
}

struct EditEventTimeView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PreviewPersistence.controller.container.viewContext

        // 더미 Baby
        let baby = Baby(context: context)
        baby.id = UUID()
        baby.name = "Preview Baby"
        baby.birthday = Date()

        // Feed Event (createdAt = 현재 시간 - 10분)
        let feed = CareEvent(context: context)
        feed.id = UUID()
        feed.kind = .feed
        feed.feedType = .formula
        feed.feedAmountML = 120
        feed.createdAt = Date().addingTimeInterval(-600)
        feed.baby = baby

        // Diaper Event (createdAt = 현재 시간 - 1시간)
        let diaper = CareEvent(context: context)
        diaper.id = UUID()
        diaper.kind = .diaper
        diaper.diaperType = .poop
        diaper.createdAt = Date().addingTimeInterval(-3600)
        diaper.baby = baby

        // Sleep Event (2시간 전 ~ 1시간 전)
        let sleep = CareEvent(context: context)
        sleep.id = UUID()
        sleep.kind = .sleep
        sleep.sleepStartAt = Date().addingTimeInterval(-7200)
        sleep.sleepEndAt = Date().addingTimeInterval(-3600)
        sleep.createdAt = sleep.sleepEndAt ?? Date()
        sleep.baby = baby

        return Group {
            EditEventTimeView(event: feed)
                .environment(\.managedObjectContext, context)
                .previewDisplayName("Feed Event")

            EditEventTimeView(event: diaper)
                .environment(\.managedObjectContext, context)
                .previewDisplayName("Diaper Event")

            EditEventTimeView(event: sleep)
                .environment(\.managedObjectContext, context)
                .previewDisplayName("Sleep Event")
        }
    }
}


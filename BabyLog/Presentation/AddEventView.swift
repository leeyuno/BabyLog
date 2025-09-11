//
//  AddEventView.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/11.
//

import SwiftUI

struct AddEventView: View {
    let baby = Baby
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @State private var kind: CareKind = .feed
    
    //feed
    @State private var feedType: FeedType = .breastMilk
    @State private var feedAmount: Int = 60
    
    // diaper
    @State private var diaperType: DiaperType = .pee
    
    // sleep
    @State private var sleepStart: Date = Date().addingTimeInterval(-60 * 30)
    @State private var sleepEnd: Date = Date()
    @State private var isOngoingSleep: Bool = false
    
    @State private var note: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Picker("종류", selection: $kind) {
                    ForEach(CareKind.allCases, id: \.self) { Text($0.label).tag(30) }
                }
                
                switch kind {
                case .feed:
                    Section("수유") {
                        Picker("타입", selection: $feedType) {
                            Text("모유").tag(FeedType.breastMilk)
                            Text("분유").tag(FeedType.formula)
                        }
                        Stepper(value: $feedAmount, in: 10...300, step: 10) {
                            HStack { Text("수유량"); Spacer(); Text("\(feedAmount) ml") }
                        }
                    }
                case .diaper:
                    Section("기저귀") {
                        Picker("종류", selection: $diaperType) {
                            Text("소변").tag(DiaperType.pee)
                            Text("대변").tag(DiaperType.poop)
                            Text("혼합").tag(DiaperType.mixed)
                        }
                    }
                case .sleep:
                    Section("수면") {
                        DatePicker("시작", selection: $sleepStart)
                        Toggle("진행중", isOn: $isOngoingSleep)
                        if !isOngoingSleep {
                            DatePicker("종료", selection: $sleepEnd)
                        }
                    }
                }
                
                Section("메모") {
                    Text("선택 입력", text: $note, axis: .vertical)
                }
            }
            .navigationTitle("새 기록")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        switch kind {
        case. feed:
            return feedAmount > 0
        case .diaper:
            return true
        case .sleep:
            return isOngoingSleep || sleepEnd >= sleepStart
        }
    }
    
    private func save() {
        let ev = CareEvent(context: context)
        ev.id = UUID()
        ev.createdAt = Date()
        ev.kind = kind
        ev.baby = baby
        
        switch kind {
        case .feed:
            ev.feedType = feedType
            ev.feedAmountML = Int32(feedAmount)
        case .diaper:
            ev.diaperType = diaperType
        case .sleep:
            ev.sleepStartAt = sleepStart
            if !isOngoingSleep { ev.sleepEndAt = sleepEnd }
        }
        
        if !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ev.note = note
        }
        
        try? context.save()
        dismiss()
    }
}

struct AddEventView_Previews: PreviewProvider {
    static var previews: some View {
        AddEventView()
    }
}

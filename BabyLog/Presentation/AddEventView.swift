//
//  AddEventView.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/11.
//
//  기록 추가 · 편집 공용 시트.
//    - 추가: AddEventView(baby:kind:)  — 타임라인 + 버튼, 위젯 딥링크(RootView 경유)
//    - 편집: AddEventView(editing:)    — 타임라인에서 기록 탭/스와이프
//
//  "아이를 안고 한 손으로" 쓰는 상황을 기준으로 입력 단계를 최소화한다.
//    - 시간 기본값은 "지금". 손대지 않으면 시트를 연 시각이 아니라 **저장 시각**으로 기록.
//    - 자주 쓰는 과거 시점은 칩 한 번(5분/15분/30분/1시간 전), 정확한 시각만 피커로.
//    - 수유량 기본값: 자동추천 OFF → 직전 수유량, ON → 최근 평균이 권장량보다 적으면 권장량
//      (규칙은 FeedingGuide.defaultFeedAmount). 편집 모드에서는 저장된 값을 그대로 보여준다.
//

import SwiftUI
import CoreData

struct AddEventView: View {
    let baby: Baby
    /// nil 이면 추가 모드, 값이 있으면 해당 기록을 편집한다.
    private let editingEvent: CareEvent?

    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var kind: CareKind

    // feed
    @State private var feedType: FeedType
    @State private var feedAmount: Int

    // diaper
    @State private var diaperType: DiaperType

    // 수유/기저귀 기록 시각
    @State private var recordedAt: Date
    /// 사용자가 시간을 직접 바꿨는지. false 면 저장 시점의 현재 시각을 쓴다(추가 모드).
    @State private var timeTouched: Bool

    // sleep
    @State private var sleepStart: Date
    @State private var sleepEnd: Date
    @State private var isOngoingSleep: Bool

    @State private var note: String
    @State private var saveError: String?
    @State private var confirmDelete = false

    /// 설정 탭의 "수유량 자동 추천" 스위치
    @AppStorage(FeedingSettings.autoRecommendKey) private var autoRecommend = false
    /// 현재 아기 프로필 기준 1회 권장량 (체중/개월수 미입력 시 nil)
    @State private var recommendedML: Int?

    /// 시간 바로가기 칩 (분 단위, 0 = 지금)
    private static let quickOffsets: [Int] = [0, 5, 15, 30, 60]

    private var isEditing: Bool { editingEvent != nil }

    // MARK: - Init

    /// 추가 모드
    init(baby: Baby, kind: CareKind = .feed) {
        self.baby = baby
        self.editingEvent = nil
        let now = Date()
        _kind = State(initialValue: kind)
        _feedType = State(initialValue: .formula)
        _feedAmount = State(initialValue: FeedingGuide.fallbackML)   // onAppear 에서 직전값/권장량으로 교체
        _diaperType = State(initialValue: .pee)
        _recordedAt = State(initialValue: now)
        _timeTouched = State(initialValue: false)
        _sleepStart = State(initialValue: now.addingTimeInterval(-30 * 60))
        _sleepEnd = State(initialValue: now)
        _isOngoingSleep = State(initialValue: false)
        _note = State(initialValue: "")
    }

    /// 편집 모드: 저장된 값으로 모든 필드를 채운다.
    init(editing event: CareEvent) {
        self.baby = event.baby
        self.editingEvent = event
        _kind = State(initialValue: event.kind)
        _feedType = State(initialValue: event.feedType ?? .formula)
        _feedAmount = State(initialValue: event.feedAmountML > 0
                            ? FeedingGuide.clamp(Int(event.feedAmountML)) : FeedingGuide.fallbackML)
        _diaperType = State(initialValue: event.diaperType ?? .pee)
        _recordedAt = State(initialValue: event.createdAt)
        _timeTouched = State(initialValue: true)     // 편집은 항상 저장된 시각 유지
        _sleepStart = State(initialValue: event.sleepStartAt ?? event.createdAt)
        _sleepEnd = State(initialValue: event.sleepEndAt ?? Date())
        _isOngoingSleep = State(initialValue: event.kind == .sleep && event.sleepEndAt == nil)
        _note = State(initialValue: event.note ?? "")
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            Form {
                Picker("종류", selection: $kind) {
                    ForEach(CareKind.allCases, id: \.self) {
                        Text($0.label).tag($0)
                    }
                }
                .pickerStyle(.segmented)          // 한 번 탭으로 전환
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                switch kind {
                case .feed:
                    feedSection
                    timeSection
                case .diaper:
                    Section("기저귀") {
                        Picker("종류", selection: $diaperType) {
                            ForEach(DiaperType.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    timeSection
                case .sleep:
                    sleepSection
                }

                Section("메모") {
                    TextField("선택 입력", text: $note, axis: .vertical)
                }

                if isEditing {
                    Section {
                        Button("기록 삭제", role: .destructive) { confirmDelete = true }
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(isEditing ? "기록 편집" : "새 기록")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: prefillIfAdding)
            .alert("저장 실패", isPresented: Binding(get: { saveError != nil },
                                                    set: { if !$0 { saveError = nil } })) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
            .confirmationDialog("이 기록을 삭제할까요?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("삭제", role: .destructive, action: deleteEvent)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장") { save() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
        }
    }

    // MARK: - Sections

    private var feedSection: some View {
        Section {
            Picker("타입", selection: $feedType) {
                Text("분유").tag(FeedType.formula)
                Text("모유").tag(FeedType.breastMilk)
            }
            .pickerStyle(.segmented)

            Stepper(value: $feedAmount, in: FeedingGuide.amountRange, step: 10) {
                HStack {
                    Text("수유량")
                    Spacer()
                    Text("\(feedAmount) ml")
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                }
            }
            if autoRecommend, let rec = recommendedML, rec != feedAmount {
                Button("권장량 \(rec) ml 적용") { feedAmount = rec }
            }
        } header: {
            Text("수유")
        } footer: {
            recommendationFooter
        }
    }

    /// 수유·기저귀 공용 시간 입력: 바로가기 칩 + 날짜/시간 피커
    private var timeSection: some View {
        Section {
            HStack(spacing: 6) {
                ForEach(Self.quickOffsets, id: \.self) { minutes in
                    quickChip(minutes)
                }
            }
            .frame(maxWidth: .infinity)

            DatePicker("시간", selection: recordedAtBinding, in: ...Date(),
                       displayedComponents: [.date, .hourAndMinute])
        } header: {
            Text("시간")
        } footer: {
            if !timeTouched {
                Text("저장하는 순간의 시각으로 기록됩니다.")
            }
        }
    }

    private func quickChip(_ minutes: Int) -> some View {
        let selected = isQuickSelected(minutes)
        let title = minutes == 0 ? "지금" : (minutes < 60 ? "\(minutes)분 전" : "\(minutes / 60)시간 전")
        return Button(title) { applyQuickOffset(minutes) }
            .buttonStyle(.bordered)               // Form 행 안에서 버튼별로 탭되도록
            .tint(selected ? .accentColor : .secondary)
            .controlSize(.small)
            .font(.caption.weight(selected ? .semibold : .regular))
    }

    private var sleepSection: some View {
        Section("수면") {
            DatePicker("시작", selection: $sleepStart, in: ...Date(),
                       displayedComponents: [.date, .hourAndMinute])
            Toggle("자는 중", isOn: $isOngoingSleep)
            if !isOngoingSleep {
                DatePicker("종료", selection: $sleepEnd, in: sleepStart...max(sleepStart, Date()),
                           displayedComponents: [.date, .hourAndMinute])
            }
        }
    }

    /// 자동추천 ON 일 때만 권장량 근거(또는 입력 안내)를 보여준다.
    @ViewBuilder
    private var recommendationFooter: some View {
        if autoRecommend {
            if let rec = recommendedML, let months = baby.ageInMonths {
                Text("권장 1회 약 \(rec) ml · 체중 \(baby.weightKg, specifier: "%.1f") kg, \(months)개월 기준 (참고용)")
            } else {
                Text("설정 탭에서 몸무게와 개월수를 입력하면 권장 수유량이 자동 계산됩니다.")
            }
        }
    }

    // MARK: - 시간 헬퍼

    /// 피커로 바꾸면 "직접 지정"으로 표시
    private var recordedAtBinding: Binding<Date> {
        Binding(get: { recordedAt },
                set: { recordedAt = $0; timeTouched = true })
    }

    private func applyQuickOffset(_ minutes: Int) {
        if minutes == 0 {
            recordedAt = Date()
            timeTouched = false          // "지금" → 저장 시각으로
        } else {
            recordedAt = Date().addingTimeInterval(Double(-minutes * 60))
            timeTouched = true
        }
    }

    /// 칩 강조: "지금"은 시간을 건드리지 않았을 때, 나머지는 현재 기준 ±1분 이내일 때
    private func isQuickSelected(_ minutes: Int) -> Bool {
        if minutes == 0 { return !timeTouched }
        guard timeTouched else { return false }
        let diff = Date().timeIntervalSince(recordedAt) / 60
        return abs(diff - Double(minutes)) < 1
    }

    // MARK: - 저장 / 삭제

    private func prefillIfAdding() {
        recommendedML = baby.recommendedPerFeedML
        guard !isEditing else { return }
        // 종류와 무관하게 미리 채워둔다(시트 안에서 수유로 바꿔도 유지)
        feedAmount = FeedingGuide.defaultFeedAmount(
            lastML: LastValueProvider.lastFeedingML(for: baby, in: context),
            recentAverageML: LastValueProvider.recentAverageFeedingML(for: baby, in: context),
            recommendedML: recommendedML,
            autoRecommend: autoRecommend
        )
    }

    private var isValid: Bool {
        switch kind {
        case .feed:
            return feedAmount > 0
        case .diaper:
            return true
        case .sleep:
            return isOngoingSleep || sleepEnd >= sleepStart
        }
    }

    private func save() {
        let ev: CareEvent
        if let editingEvent {
            ev = editingEvent
        } else {
            ev = CareEvent(context: context)
            ev.id = UUID()
            ev.baby = baby
        }
        ev.kind = kind

        // 종류가 바뀌었을 수 있으므로 해당 종류 필드만 남기고 나머지는 비운다.
        // (nil 센티널 Int16.min — 기본값 0 이 모유/소변으로 오해되지 않도록)
        ev.feedType = nil
        ev.feedAmountML = 0
        ev.diaperType = nil
        ev.sleepStartAt = nil
        ev.sleepEndAt = nil

        let eventTime = timeTouched ? recordedAt : Date()
        switch kind {
        case .feed:
            ev.feedType = feedType
            ev.feedAmountML = Int32(feedAmount)
            ev.createdAt = eventTime
        case .diaper:
            ev.diaperType = diaperType
            ev.createdAt = eventTime
        case .sleep:
            ev.sleepStartAt = sleepStart
            if !isOngoingSleep { ev.sleepEndAt = sleepEnd }
            // 수면의 기준 시각은 종료(자는 중이면 시작) 시각 — CareEvent 문서 참고
            ev.createdAt = isOngoingSleep ? sleepStart : sleepEnd
        }

        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        ev.note = trimmed.isEmpty ? nil : trimmed

        do {
            try context.saveAndRefreshWidgets()
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func deleteEvent() {
        guard let editingEvent else { return }
        context.delete(editingEvent)
        do {
            try context.saveAndRefreshWidgets()
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

struct AddEventView_Previews: PreviewProvider {
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
        let eventReq: NSFetchRequest<CareEvent> = CareEvent.fetchRequest()
        let event = try? context.fetch(eventReq).first

        return Group {
            AddEventView(baby: baby)
                .previewDisplayName("추가")
            if let event {
                AddEventView(editing: event)
                    .previewDisplayName("편집")
            }
        }
        .environment(\.managedObjectContext, context)
    }
}

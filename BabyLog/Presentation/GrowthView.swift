//
//  GrowthView.swift
//  BabyLog
//
//  Created by 이윤오 on 2026/11/18.
//
//  성장 탭: 프로필(사진·이름·개월수) + 개월수별 몸무게 차트 + 기록 목록.
//  - x축: 생일 기준 개월수(소수). 생일이 없으면 날짜 축으로 대신 그린다.
//  - 몸무게는 하루 한 건(같은 날 다시 입력하면 갱신). 설정 탭에서 몸무게를 바꿔도 오늘 기록으로 쌓인다.
//  - 기록이 바뀌면 Baby.weightKg(최신값)가 갱신되어 수유량 자동 추천에도 반영된다.
//

import Charts
import CoreData
import SwiftUI

struct GrowthView: View {
    @ObservedObject var baby: Baby
    @Environment(\.managedObjectContext) private var context
    @FetchRequest private var records: FetchedResults<WeightRecord>

    @State private var showEntry = false
    @State private var editing: WeightRecord?

    init(baby: Baby) {
        self.baby = baby
        _records = FetchRequest(
            sortDescriptors: [NSSortDescriptor(key: #keyPath(WeightRecord.measuredAt), ascending: true)],
            predicate: NSPredicate(format: "baby == %@", baby),
            animation: .default
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section { profileHeader }
                Section("몸무게 변화") { chartSection }
                Section {
                    if records.isEmpty {
                        Text("아직 기록이 없어요.").foregroundStyle(.secondary)
                    }
                    ForEach(records.reversed()) { r in
                        Button { editing = r } label: { recordRow(r) }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) { delete(r) } label: { Label("삭제", systemImage: "trash") }
                            }
                    }
                } header: {
                    Text("기록")
                } footer: {
                    Text("하루에 한 번만 저장됩니다. 같은 날짜로 다시 입력하면 그 날 기록이 바뀝니다.")
                }
            }
            .navigationTitle("성장")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showEntry = true } label: { Label("몸무게 기록", systemImage: "plus.circle.fill") }
                }
            }
            .sheet(isPresented: $showEntry) {
                WeightEntrySheet(baby: baby, record: nil, defaultWeight: records.last?.weightKg ?? baby.weightKg)
                    .environment(\.managedObjectContext, context)
            }
            .sheet(item: $editing) { r in
                if !r.isDeleted, r.managedObjectContext != nil {
                    WeightEntrySheet(baby: baby, record: r, defaultWeight: r.weightKg)
                        .environment(\.managedObjectContext, context)
                }
            }
            .onAppear(perform: seedFromSettingsWeight)
        }
    }

    // MARK: - 프로필

    private var profileHeader: some View {
        HStack(spacing: 16) {
            BabyAvatarView(baby: baby, size: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text(baby.name).font(.title2.bold())
                if let birthday = baby.birthday {
                    Text(GrowthMath.ageText(birthday: birthday)).foregroundStyle(.secondary)
                } else if let months = baby.ageInMonths {
                    Text("\(months)개월").foregroundStyle(.secondary)
                }
                if let last = records.last {
                    let day = last.measuredAt.formatted(.dateTime.month().day())
                    Text("\(last.weightKg, specifier: "%.2f") kg · \(day)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    // MARK: - 차트

    private struct Point: Identifiable {
        let id: NSManagedObjectID
        let x: Double        // 개월수
        let date: Date
        let kg: Double
    }

    private var points: [Point] {
        records.map { r in
            Point(id: r.objectID,
                  x: baby.birthday.map { GrowthMath.ageMonths(birthday: $0, at: r.measuredAt) } ?? 0,
                  date: r.measuredAt,
                  kg: r.weightKg)
        }
    }

    @ViewBuilder
    private var chartSection: some View {
        let pts = points
        if pts.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis").font(.largeTitle).foregroundStyle(.secondary)
                Text("몸무게를 기록하면 개월수별 성장 그래프가 그려져요.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("첫 몸무게 기록하기") { showEntry = true }.buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                chart(pts)
                    .frame(height: 220)
                gainSummary(pts)
                if baby.birthday == nil {
                    Text("설정에서 생일을 입력하면 개월수 기준으로 볼 수 있어요.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func chart(_ pts: [Point]) -> some View {
        let kgs = pts.map(\.kg)
        let lo = max((kgs.min() ?? 0) - 0.5, 0), hi = (kgs.max() ?? 1) + 0.5
        let byAge = baby.birthday != nil
        return Chart(pts) { p in
            if byAge {
                LineMark(x: .value("개월", p.x), y: .value("kg", p.kg))
                    .interpolationMethod(.monotone)
                PointMark(x: .value("개월", p.x), y: .value("kg", p.kg))
            } else {
                LineMark(x: .value("날짜", p.date), y: .value("kg", p.kg))
                    .interpolationMethod(.monotone)
                PointMark(x: .value("날짜", p.date), y: .value("kg", p.kg))
            }
        }
        .chartYScale(domain: lo...hi)
        .chartYAxisLabel("kg")
        .chartXAxisLabel(byAge ? "개월" : "")
    }

    /// 직전 기록 대비 증감
    @ViewBuilder
    private func gainSummary(_ pts: [Point]) -> some View {
        if pts.count >= 2 {
            let last = pts[pts.count - 1], prev = pts[pts.count - 2]
            let diff = last.kg - prev.kg
            let days = Calendar.current.dateComponents([.day], from: prev.date, to: last.date).day ?? 0
            Text("직전 기록보다 \(diff >= 0 ? "+" : "")\(diff, specifier: "%.2f") kg (\(days)일 동안)")
                .font(.subheadline)
                .foregroundStyle(diff >= 0 ? Color.green : Color.orange)
        }
    }

    private func recordRow(_ r: WeightRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(r.measuredAt.formatted(.dateTime.year().month().day()))
                if let birthday = baby.birthday {
                    Text(GrowthMath.ageText(birthday: birthday, now: r.measuredAt))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("\(r.weightKg, specifier: "%.2f") kg").font(.body.monospacedDigit().weight(.semibold))
        }
        .contentShape(Rectangle())
    }

    // MARK: - 데이터

    private func delete(_ r: WeightRecord) {
        GrowthStore.delete(r, of: baby, in: context)
        try? context.saveAndRefreshWidgets()
    }

    /// 성장 기록 도입 전 설정에서 입력한 몸무게를 첫 기록으로
    private func seedFromSettingsWeight() {
        if GrowthStore.seedIfNeeded(for: baby, in: context) {
            try? context.saveAndRefreshWidgets()
        }
    }
}

/// 몸무게 입력 시트 (추가/수정 공용). 날짜 기본값은 오늘, 몸무게 기본값은 직전 기록.
struct WeightEntrySheet: View {
    let baby: Baby
    let record: WeightRecord?
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date
    @State private var weightText: String
    @State private var errorMessage: String?
    @FocusState private var focused: Bool

    private static let range = 0.5...30.0

    init(baby: Baby, record: WeightRecord?, defaultWeight: Double) {
        self.baby = baby
        self.record = record
        _date = State(initialValue: record?.measuredAt ?? Date())
        _weightText = State(initialValue: defaultWeight > 0 ? String(format: "%.2f", defaultWeight) : "")
    }

    private var parsed: Double? {
        let t = weightText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let v = Double(t), Self.range.contains(v) else { return nil }
        return v
    }

    private var earliest: Date { baby.birthday ?? Date.distantPast }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        TextField("예: 6.25", text: $weightText)
                            .keyboardType(.decimalPad)
                            .font(.title2.weight(.semibold).monospacedDigit())
                            .focused($focused)
                        Text("kg").foregroundStyle(.secondary)
                    }
                    // 저울 숫자를 옮겨 적는 경우가 많아 ±50g 버튼으로도 조절
                    HStack(spacing: 12) {
                        ForEach([-0.05, 0.05], id: \.self) { step in
                            Button(step > 0 ? "+50g" : "−50g") { adjust(step) }
                                .buttonStyle(.bordered)
                        }
                    }
                } header: {
                    Text("몸무게")
                } footer: {
                    if !weightText.isEmpty && parsed == nil {
                        Text("0.5~30 kg 사이 숫자로 입력하세요.").foregroundStyle(.red)
                    }
                }
                Section("날짜") {
                    DatePicker("측정일", selection: $date, in: earliest...Date(), displayedComponents: .date)
                }
                if let record {
                    Section {
                        Button("기록 삭제", role: .destructive) {
                            GrowthStore.delete(record, of: baby, in: context)
                            commit()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(record == nil ? "몸무게 기록" : "몸무게 수정")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { focused = record == nil }
            .alert("저장 실패", isPresented: Binding(get: { errorMessage != nil },
                                                    set: { if !$0 { errorMessage = nil } })) {
                Button("확인", role: .cancel) {}
            } message: { Text(errorMessage ?? "") }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("닫기") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장", action: save).fontWeight(.semibold).disabled(parsed == nil)
                }
            }
        }
    }

    private func adjust(_ step: Double) {
        let base = parsed ?? 0
        let next = min(max(base + step, Self.range.lowerBound), Self.range.upperBound)
        weightText = String(format: "%.2f", next)
    }

    private func save() {
        guard let kg = parsed else { return }
        if let record, !Calendar.current.isDate(record.measuredAt, inSameDayAs: date) {
            // 날짜를 바꾼 수정: 기존 기록을 지우고 새 날짜로 넣는다(그 날짜 기록이 있으면 합쳐짐)
            GrowthStore.delete(record, of: baby, in: context)
        }
        GrowthStore.upsert(weightKg: kg, on: date, for: baby, in: context)
        commit()
    }

    private func commit() {
        do {
            try context.saveAndRefreshWidgets()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

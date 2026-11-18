//
//  SettingsView.swift
//  BabyLog
//
//  Created by 이윤오 on 2026/11/16.
//
//  설정 탭: 아기 프로필 사진 + 아기 정보(이름·생일/개월수·몸무게) 수정 + 수유량 자동 추천 on/off.
//  - 사진: PhotosPicker → BabyPhotoStore (정사각형 600px JPEG, 즉시 저장)
//  - 몸무게를 바꿔 저장하면 오늘 날짜의 성장 기록(WeightRecord)으로 쌓인다 → 성장 탭 차트
//  - 개월수: 생일이 있으면 자동 계산, 없으면 직접 입력(Baby.manualAgeMonths)
//  - 자동 추천 스위치는 @AppStorage(FeedingSettings.autoRecommendKey) — AddEventView 와 공유
//  - 입력값은 로컬 상태로 편집하고 "저장" 시 Core Data 에 반영한다.
//

import CoreData
import PhotosUI
import SwiftUI

struct SettingsView: View {
    @ObservedObject var baby: Baby
    @Environment(\.managedObjectContext) private var context

    @AppStorage(FeedingSettings.autoRecommendKey) private var autoRecommend = false

    // 편집용 로컬 상태
    @State private var name: String
    @State private var hasBirthday: Bool
    @State private var birthday: Date
    @State private var manualMonths: Int
    /// 몸무게 입력 문자열. TextField(value:) 는 포커스 해제 전까지 값이 반영되지 않아 문자열로 받는다.
    @State private var weightText: String

    @State private var alertMessage: String?
    @State private var photoItem: PhotosPickerItem?
    @ObservedObject private var photos = BabyPhotoStore.shared
    @FocusState private var weightFocused: Bool

    /// 입력 허용 체중 범위(kg)
    private static let weightRange = 0.5...30.0
    private static let weightHint = String(
        format: "몸무게는 %.1f~%.0f kg 사이 숫자로 입력하세요.",
        weightRange.lowerBound,
        weightRange.upperBound
    )

    init(baby: Baby) {
        self.baby = baby
        _name = State(initialValue: baby.name)
        _hasBirthday = State(initialValue: baby.birthday != nil)
        _birthday = State(initialValue: baby.birthday ?? Date())
        _manualMonths = State(initialValue: max(Int(baby.manualAgeMonths), 0))
        _weightText = State(initialValue: baby.weightKg > 0 ? String(format: "%.1f", baby.weightKg) : "")
    }

    // MARK: - 파생 값

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// 입력 문자열 → kg. 비어 있으면 0(미입력), 형식 오류/범위 밖이면 nil.
    private var parsedWeight: Double? {
        let t = weightText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        if t.isEmpty { return 0 }
        guard let v = Double(t), Self.weightRange.contains(v) else { return nil }
        return v
    }

    private var draftAgeMonths: Int {
        hasBirthday ? FeedingGuide.ageInMonths(birthday: birthday) : manualMonths
    }

    private var draftRecommendedML: Int? {
        FeedingGuide.recommendedPerFeedML(weightKg: parsedWeight ?? 0, ageMonths: draftAgeMonths)
    }

    private var hasChanges: Bool {
        trimmedName != baby.name
            || hasBirthday != (baby.birthday != nil)
            || (hasBirthday && birthday != baby.birthday)
            || (!hasBirthday && manualMonths != Int(baby.manualAgeMonths))
            || (parsedWeight ?? -1) != baby.weightKg
    }

    private var canSave: Bool { hasChanges && !trimmedName.isEmpty && parsedWeight != nil }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                photoSection
                babySection
                feedingSection
                Section {
                    Button("저장", action: save)
                        .frame(maxWidth: .infinity)
                        .disabled(!canSave)
                }
            }
            .navigationTitle("설정")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("완료") { weightFocused = false }
                }
            }
            .alert(alertMessage ?? "", isPresented: Binding(get: { alertMessage != nil },
                                                           set: { if !$0 { alertMessage = nil } })) {
                Button("확인", role: .cancel) {}
            }
        }
    }

    private var photoSection: some View {
        Section {
            HStack(spacing: 16) {
                BabyAvatarView(baby: baby, size: 64)
                VStack(alignment: .leading, spacing: 8) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(photos.image(for: baby.id) == nil ? "사진 선택" : "사진 변경", systemImage: "photo")
                    }
                    if photos.image(for: baby.id) != nil {
                        Button("사진 삭제", role: .destructive) { photos.delete(for: baby.id) }
                            .buttonStyle(.borderless)
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("프로필 사진")
        }
        .onChange(of: photoItem) { item in
            guard let item else { return }
            Task {
                do {
                    if let data = try await item.loadTransferable(type: Data.self) {
                        try await MainActor.run { try photos.save(imageData: data, for: baby.id) }
                    }
                } catch {
                    await MainActor.run { alertMessage = "사진 저장 실패: \(error.localizedDescription)" }
                }
                await MainActor.run { photoItem = nil }
            }
        }
    }

    private var babySection: some View {
        Section {
            TextField("이름", text: $name)
                .disableAutocorrection(true)

            Toggle("생일 입력", isOn: $hasBirthday)
            if hasBirthday {
                DatePicker("생일", selection: $birthday, in: ...Date(), displayedComponents: .date)
                LabeledContent("개월수", value: "\(draftAgeMonths)개월")
            } else {
                Stepper(value: $manualMonths, in: 0...36) {
                    LabeledContent("개월수", value: "\(manualMonths)개월")
                }
            }

            HStack {
                Text("몸무게")
                Spacer()
                TextField("예: 5.2", text: $weightText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($weightFocused)
                    .frame(maxWidth: 100)
                Text("kg").foregroundStyle(.secondary)
            }
        } header: {
            Text("아기 정보")
        } footer: {
            if parsedWeight == nil {
                Text(Self.weightHint)
                    .foregroundStyle(.red)
            } else {
                Text("몸무게를 바꿔 저장하면 오늘 날짜로 성장 기록에 추가됩니다. 지난 기록은 성장 탭에서 관리하세요.")
            }
        }
    }

    private var feedingSection: some View {
        Section {
            Toggle("수유량 자동 추천", isOn: $autoRecommend)
            if autoRecommend {
                if let rec = draftRecommendedML {
                    LabeledContent("1회 권장량", value: "약 \(rec) ml")
                    LabeledContent("하루 수유 횟수", value: "\(FeedingGuide.feedsPerDay(ageMonths: draftAgeMonths))회")
                } else {
                    Text("몸무게를 입력하면 권장 수유량이 계산됩니다.")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("수유")
        } footer: {
            if autoRecommend {
                Text("최근 평균 수유량이 권장량보다 적으면 새 기록의 기본값이 권장량으로 바뀝니다. "
                     + "권장량은 체중×150 ml(하루 최대 1,000 ml)를 개월수별 하루 수유 횟수로 나눈 참고값이며, "
                     + "아기마다 다를 수 있으니 정확한 수유량은 소아청소년과 전문의와 상담하세요.")
            } else {
                Text("꺼져 있으면 직전에 기록한 수유량이 기본값으로 사용됩니다.")
            }
        }
    }

    // MARK: - 저장

    private func save() {
        guard let weight = parsedWeight else { return }
        weightFocused = false

        baby.name = trimmedName
        baby.birthday = hasBirthday ? birthday : nil
        baby.manualAgeMonths = hasBirthday ? -1 : Int16(manualMonths)
        if weight > 0, weight != baby.weightKg {
            // 몸무게 변경은 오늘 날짜 성장 기록으로 남긴다 (Baby.weightKg 도 함께 갱신됨)
            GrowthStore.upsert(weightKg: weight, on: Date(), for: baby, in: context)
        } else if weight == 0 {
            baby.weightKg = 0
        }

        do {
            try context.saveAndRefreshWidgets()
            alertMessage = "저장되었습니다."
        } catch {
            alertMessage = "저장 실패: \(error.localizedDescription)"
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PreviewPersistence.controller.container.viewContext
        let baby = (try? context.fetch(Baby.fetchRequest() as NSFetchRequest<Baby>).first) ?? Baby(context: context)
        return SettingsView(baby: baby)
            .environment(\.managedObjectContext, context)
    }
}

//
//  SettingsView.swift
//  BabyLog
//
//  Created by 이윤오 on 2026/11/16.
//
//  설정 탭: 아기 프로필 사진 + 아기 정보(이름·생일/개월수·몸무게) 수정 + 수유량 자동 추천 on/off.
//  - 사진: PhotosPicker → BabyPhotoStore (정사각형 600px JPEG, 즉시 저장)
//  - 몸무게를 바꿔 저장하면 오늘 날짜의 성장 기록(WeightRecord)으로 쌓인다 → 성장 탭 차트
//  - 성별: WHO 성장곡선 비교에만 사용 / 다음 수유 알림: FeedReminder (즉시 반영)
//  - 데이터: 백업 파일 만들기(fileExporter) / 백업에서 복원(fileImporter → 확인 → 전체 교체). Android 와 같은 형식
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
    @AppStorage(FeedReminder.enabledKey) private var reminderOn = false
    @AppStorage(FeedReminder.leadMinutesKey) private var reminderLead = 0
    @AppStorage(NightMode.storageKey) private var nightModeRaw = NightMode.auto.rawValue

    // 편집용 로컬 상태
    @State private var name: String
    @State private var hasBirthday: Bool
    @State private var birthday: Date
    @State private var manualMonths: Int
    @State private var sex: BabySex
    /// 몸무게 입력 문자열. TextField(value:) 는 포커스 해제 전까지 값이 반영되지 않아 문자열로 받는다.
    @State private var weightText: String

    @State private var alertMessage: String?
    @State private var photoItem: PhotosPickerItem?
    @State private var backupDocument: BackupDocument?
    @State private var showImporter = false
    @State private var pendingRestore: BackupPayload?
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
        _sex = State(initialValue: baby.sex)
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
            || sex != baby.sex
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
                reminderSection
                displaySection
                dataSection
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

            Picker("성별", selection: $sex) {
                ForEach(BabySex.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

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

    private var dataSection: some View {
        Section {
            Button("백업 파일 만들기") {
                do {
                    backupDocument = BackupDocument(data: try BackupService.exportData(context: context))
                } catch {
                    alertMessage = "백업 실패: \(error.localizedDescription)"
                }
            }
            Button("백업에서 복원") { showImporter = true }
        } header: {
            Text("데이터")
        } footer: {
            Text("기록은 이 폰에만 저장돼요. 기기를 바꾸기 전에 백업 파일을 iCloud Drive 나 메신저로 보관하세요. "
                 + "안드로이드 앱의 백업 파일도 그대로 불러올 수 있어요.")
        }
        .fileExporter(isPresented: Binding(get: { backupDocument != nil }, set: { if !$0 { backupDocument = nil } }),
                      document: backupDocument, contentType: .json,
                      defaultFilename: BackupDocument.defaultFilename()) { result in
            if case .failure(let error) = result { alertMessage = "백업 실패: \(error.localizedDescription)" }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                pendingRestore = try BackupService.decode(Data(contentsOf: url))
            } catch {
                alertMessage = "복원 실패: \(error.localizedDescription)"
            }
        }
        .confirmationDialog(restoreTitle, isPresented: Binding(get: { pendingRestore != nil },
                                                               set: { if !$0 { pendingRestore = nil } }),
                            titleVisibility: .visible) {
            Button("지금 기록을 지우고 복원", role: .destructive, action: restore)
        } message: {
            Text("현재 이 폰의 기록은 모두 지워지고 백업 내용으로 바뀝니다. 되돌릴 수 없어요.")
        }
    }

    private var restoreTitle: String {
        guard let p = pendingRestore else { return "" }
        let name = p.babies.first?.name ?? "아기"
        return "\(name) · 기록 \(p.events.count)건 · 몸무게 \(p.weights.count)건으로 복원할까요?"
    }

    private func restore() {
        guard let payload = pendingRestore else { return }
        pendingRestore = nil
        do {
            let counts = try BackupService.replaceAll(with: payload, context: context)
            try context.saveAndRefreshWidgets()
            alertMessage = "복원했어요. 기록 \(counts.events)건, 몸무게 \(counts.weights)건"
        } catch {
            context.rollback()
            alertMessage = "복원 실패: \(error.localizedDescription)"
        }
    }

    private var displaySection: some View {
        Section {
            Picker("밤 모드", selection: $nightModeRaw) {
                ForEach(NightMode.allCases, id: \.rawValue) { Text($0.label).tag($0.rawValue) }
            }
        } header: {
            Text("화면")
        } footer: {
            Text("밤 모드에서는 화면이 어둡고 따뜻한 색으로 바뀌고 글자와 버튼이 커져요. 새벽 수유 때 아이가 깨지 않도록.")
        }
    }

    private var reminderSection: some View {
        Section {
            Toggle("다음 수유 알림", isOn: $reminderOn)
            if reminderOn {
                Picker("알림 시점", selection: $reminderLead) {
                    ForEach(FeedReminder.leadOptions, id: \.self) { m in
                        Text(m == 0 ? "예상 시각" : "\(m)분 전").tag(m)
                    }
                }
            }
        } header: {
            Text("알림")
        } footer: {
            Text("최근 수유 간격으로 예상한 다음 수유 시각에 알려줍니다. 수유를 기록할 때마다 시각이 다시 계산됩니다.")
        }
        .onChange(of: reminderOn) { on in
            guard on else { FeedReminder.cancel(); return }
            Task {
                if await FeedReminder.requestAuthorization() {
                    await MainActor.run { FeedReminder.reschedule(context: context) }
                } else {
                    await MainActor.run {
                        reminderOn = false
                        alertMessage = "알림이 꺼져 있어요. 설정 앱 > 베이비로그에서 알림을 허용해 주세요."
                    }
                }
            }
        }
        .onChange(of: reminderLead) { _ in FeedReminder.reschedule(context: context) }
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
        baby.sex = sex
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

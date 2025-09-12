//
//  OnboardingNewBabyView.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/11.
//

import SwiftUI
import CoreData

struct OnboardingNewBabyView: View {
    @Environment(\.managedObjectContext) private var context

    @State private var name: String = ""
    @State private var useBirthday: Bool = true
    @State private var birthday: Date = Date()

    var body: some View {
        NavigationView {                      // ✅ iOS15 안전
            Form {
                Section(header: Text("아기 정보")) {
                    TextField("이름", text: $name)
                        .disableAutocorrection(true)

                    Toggle("생일 입력", isOn: $useBirthday)

                    if useBirthday {
                        DatePicker("생일", selection: $birthday, displayedComponents: .date)
                    }
                }

                Section {
                    Button(action: save) {    // ✅ 별도 함수로 분리(컴파일러 안정)
                        Text("시작하기")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("아기 등록")
        }
    }

    private func save() {
        let baby = Baby(context: context)
        baby.id = UUID()
        baby.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Baby" : name
        baby.birthday = useBirthday ? birthday : nil

        do {
            try context.save()
        } catch {
            // 디버깅용: 실제 앱이면 사용자 알림 처리
            print("Core Data save error:", error.localizedDescription)
        }
    }
}

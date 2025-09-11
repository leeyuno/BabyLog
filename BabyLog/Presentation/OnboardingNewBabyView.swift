//
//  OnboardingNewBabyView.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/11.
//

import SwiftUI

struct OnboardingNewBabyView: View {
    @Environment(\.managedObjectContext) private var context
    @State private var name: String = ""
    @State private var birthday: Date = Date()
    
    var body: some View {
        VStack(spacing: 16) {
            Text("아기 정보").font(.title2).bold
            TextField("이름", text: $name)
                .textFieldStyle(.roundedBorder)
            DatePicker("생일 선택", selection: $birthday, displayedComponents: .date)
            
            Button("시작하기") {
                let baby = Baby(context: context)
                baby.id = UUID()
                baby.name = name.isEmpty ? "Baby" : name
                baby.birthday = birthday
                try? context.save()
            }
            .buttonStyle(.borderedProminent)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}

struct OnboardingNewBabyView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingNewBabyView()
    }
}

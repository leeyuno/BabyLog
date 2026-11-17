//
//  AddQuickHomeWidgetView.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/23.
//
//  "빠른 기록 추가" 위젯의 홈 화면(systemSmall/Medium) UI. 앱·위젯 두 타깃에 포함.
//  탭 → babylog://add?type=feeding → RootView 가 새 기록 시트(수유)를 띄운다.
//

import SwiftUI
import WidgetKit

struct AddQuickHomeWidgetView: View {
    var kind: AddKind = .feeding

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill").font(.title)
            Text("기록 추가").font(.headline)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(DeepLink.add(kind))  // 최상위 컨테이너에 부착해야 위젯 전체가 탭 영역이 된다
    }
}

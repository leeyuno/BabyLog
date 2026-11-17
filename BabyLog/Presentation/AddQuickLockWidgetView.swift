//
//  AddQuickLockWidgetView.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/23.
//
//  "빠른 기록 추가" 위젯의 잠금화면(accessory*) UI. 앱·위젯 두 타깃에 포함.
//

import SwiftUI

struct AddQuickLockWidgetView: View {
    var kind: AddKind = .feeding

    var body: some View {
        ZStack {
            Text("+ 추가").font(.caption)
        }
        .widgetURL(DeepLink.add(kind))
    }
}

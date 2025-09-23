//
//  AddQuickLockWidgetView.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/23.
//

import SwiftUI

struct AddQuickLockWidgetView: View {
    var body: some View {
        ZStack {
            // accessoryCircular/Rectangular/Inline UI…
            Text("+ 추가").font(.caption)
        }
        .widgetURL(URL(string: "babylog://add?type=feed")!) // ⬅️ 핵심
    }
}

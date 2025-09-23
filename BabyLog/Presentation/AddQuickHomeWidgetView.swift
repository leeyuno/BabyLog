//
//  AddQuickHomeWidgetView.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/23.
//

import SwiftUI
import WidgetKit

fileprivate func makeDeepLink(_ kind: String) -> URL {
    var comp = URLComponents()
    comp.scheme = "babylog"
    comp.host = "add"
    comp.queryItems = [.init(name: "type", value: kind)]
    return comp.url!
}

struct AddQuickHomeWidgetView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill").font(.title)
                Text("기록 추가").font(.headline)
            }
            .padding()
        }
        .widgetURL(makeDeepLink("feed"))  // ⬅️ 최상위 컨테이너에 부착
    }
}

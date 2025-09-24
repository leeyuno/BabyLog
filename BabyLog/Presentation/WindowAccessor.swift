//
//  WindowAccessor.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/24.
//

import SwiftUI
import UIKit

struct WindowAccessor: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView { AccessorView() }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

private final class AccessorView: UIView {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let w = window {
            AppOpenAdManager.shared.attach(window: w)   // ✅ 윈도우 캐시
        }
    }
}

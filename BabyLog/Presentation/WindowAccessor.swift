//
//  WindowAccessor.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/24.
//
//  SwiftUI 뷰 계층에서 UIWindow 를 얻어 AppOpenAdManager 에 전달하는 0-크기 뷰.
//  RootView 의 .background(WindowAccessor()) 로 부착된다.
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

//
//  NightMode.swift
//  BabyLog
//
//  Created by 이윤오 on 2026/11/18.
//
//  밤 모드 (앱 타깃 전용). 새벽 수유 때 아이를 깨우지 않고, 졸린 눈으로도 누를 수 있게.
//  - 자동: 22:00 ~ 05:59 / 항상 / 끄기  (설정 탭, 기본값 자동)
//  - 켜지면: 다크 모드 + 따뜻한 호박색 강조색(파란빛 줄임) + 글자·버튼 한 단계 크게
//  Android lib/domain/night_mode.dart 와 같은 규칙.
//

import SwiftUI

enum NightMode: String, CaseIterable {
    case auto, always, off

    static let storageKey = "display.nightMode"
    static let startHour = 22
    static let endHour = 6       // 6시 정각부터는 낮

    var label: String {
        switch self {
        case .auto: return "자동 (22시~6시)"
        case .always: return "항상"
        case .off: return "끄기"
        }
    }

    /// 지금 밤 모드를 적용할지
    func isActive(at date: Date = Date(), calendar: Calendar = .current) -> Bool {
        switch self {
        case .always: return true
        case .off: return false
        case .auto:
            let h = calendar.component(.hour, from: date)
            return h >= Self.startHour || h < Self.endHour
        }
    }

    /// 파란빛이 적은 호박색 강조색
    static let accent = Color(red: 1.0, green: 0.72, blue: 0.42)
}

/// 루트 뷰에 적용: 1분마다 시간을 다시 보고 밤 모드를 켜고 끈다
struct NightModeModifier: ViewModifier {
    @AppStorage(NightMode.storageKey) private var raw = NightMode.auto.rawValue
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        SwiftUI.TimelineView(.everyMinute) { context in
            let mode = NightMode(rawValue: raw) ?? .auto
            if mode.isActive(at: context.date) {
                content
                    .preferredColorScheme(.dark)
                    .tint(NightMode.accent)
                    .environment(\.dynamicTypeSize, Self.bumped(dynamicTypeSize))
            } else {
                content
            }
        }
    }

    /// 글자 크기 한 단계 키우기 (이미 가장 크면 그대로)
    static func bumped(_ size: DynamicTypeSize) -> DynamicTypeSize {
        let all = DynamicTypeSize.allCases
        guard let i = all.firstIndex(of: size), i + 1 < all.count else { return size }
        return all[i + 1]
    }
}

extension View {
    func nightMode() -> some View { modifier(NightModeModifier()) }
}

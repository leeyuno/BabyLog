//
//  Constant.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/21.
//

import Foundation
import SwiftUI
import Combine

enum AddKind: String, CaseIterable {
    case sleep
    case feeding
    case diaper
}
/// 앱 내 네비게이션 목적지
enum AppRoute: Equatable {
    case none
    case add(AddKind)   // 기존 CareKind 재사용: sleep / feeding / diaper
}

/// URL → AppRoute로 변환하는 라우터
final class Router: ObservableObject {
    @Published var route: AppRoute = .none
    
    /// babylog://add?type=sleep|feeding|diaper
    func handle(url: URL) {
        guard url.scheme == "babylog" else { return }
        if url.host == "add" {
            let type = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "type" })?.value ?? "sleep"
            if let kind = AddKind(rawValue: type) {
                route = .add(kind)
            }
        }
    }
    
    func openAdd(_ kind: AddKind) {
        route = .add(kind)
    }
    
    func reset() { route = .none }
}

extension AddKind {
    /// CareKind → AddKind
    init(from care: CareKind) {
        switch care {
        case .sleep:   self = .sleep
        case .feed:    self = .feeding
        case .diaper:  self = .diaper
        @unknown default:
            self = .sleep
        }
    }
}

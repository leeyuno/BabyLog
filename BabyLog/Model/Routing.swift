//
//  Routing.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/21.
//
//  딥링크 라우팅. 앱·위젯 두 타깃에 포함된다(위젯은 URL 생성용으로 AddKind/DeepLink 사용).
//
//  지원 URL: babylog://add?type=sleep|feeding|diaper   (type=feed 도 feeding 의 별칭으로 허용)
//

import Foundation
import SwiftUI
import Combine

/// 딥링크/빠른추가에서 쓰는 기록 종류.
/// ⚠️ rawValue 는 URL 쿼리 값으로 노출되므로 변경 시 이미 설치된 위젯 링크가 깨진다.
/// CareKind(.feed) 와 이름이 다름에 주의 (.feeding).
enum AddKind: String, CaseIterable {
    case sleep
    case feeding
    case diaper

    /// URL 쿼리 값 → AddKind. 과거 위젯이 보내던 "feed" 도 수용한다.
    init?(queryValue: String) {
        if queryValue == "feed" { self = .feeding; return }
        self.init(rawValue: queryValue)
    }
}

/// 딥링크 URL 생성기 (앱·위젯 공용)
enum DeepLink {
    static let scheme = "babylog"

    static func add(_ kind: AddKind) -> URL {
        var comp = URLComponents()
        comp.scheme = scheme
        comp.host = "add"
        comp.queryItems = [URLQueryItem(name: "type", value: kind.rawValue)]
        // 고정된 구성요소이므로 nil이 될 수 없다
        guard let url = comp.url else { preconditionFailure("딥링크 URL 조립 실패: \(kind.rawValue)") }
        return url
    }
}

/// 앱 내 네비게이션 목적지
enum AppRoute: Equatable {
    case none
    case add(AddKind)
}

/// URL → AppRoute 변환 및 현재 라우트 보관.
/// RootView 가 `route` 변화를 관찰해 시트를 띄우고, 시트가 닫히면 `reset()` 해야
/// 같은 딥링크가 연속으로 들어와도 onChange 가 다시 발화한다.
final class Router: ObservableObject {
    @Published var route: AppRoute = .none

    func handle(url: URL) {
        guard url.scheme == DeepLink.scheme, url.host == "add" else { return }
        let type = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "type" })?.value ?? AddKind.feeding.rawValue
        if let kind = AddKind(queryValue: type) {
            route = .add(kind)
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
        }
    }
}

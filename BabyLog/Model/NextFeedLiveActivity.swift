//
//  NextFeedLiveActivity.swift
//  BabyLog
//
//  Created by 이윤오 on 2026/11/19.
//
//  잠금화면·다이나믹 아일랜드의 "다음 수유" 라이브 액티비티 시작/갱신/종료 (앱 타깃 전용).
//  - FeedReminder.reschedule 과 같은 시점에 sync() — 기록 저장, 앱 활성화, 설정 변경
//  - 예측이 없거나(수유 3회 미만) 예상 시각에서 2시간 넘게 지났으면 종료
//  - 설정 "잠금화면에 다음 수유 표시"(기본 켜짐) / 시스템 설정에서 라이브 액티비티를 끄면 표시 안 함
//  ⚠️ 라이브 액티비티는 앱이 화면에 있을 때만 시작할 수 있다. 위젯 원탭 기록은 앱을 열 때 반영된다.
//     iOS 가 8시간 뒤 자동 종료하지만 보통 그 전에 다음 수유 기록으로 갱신된다.
//

import ActivityKit
import Foundation

enum NextFeedLiveActivity {
    static let enabledKey = "lockscreen.nextFeed.enabled"
    /// 예상 시각이 이만큼 지나면 표시를 내린다
    static let overdueLimit: TimeInterval = 2 * 3600

    /// 기본값 켜짐 (한 번도 바꾸지 않았으면 true)
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    /// 표시할 상태 (순수 로직 — 테스트 대상). nil 이면 내린다.
    static func contentState(for prediction: FeedSchedule.Prediction?, now: Date = Date())
        -> NextFeedAttributes.ContentState? {
        guard let p = prediction, now.timeIntervalSince(p.next) <= overdueLimit else { return nil }
        return .init(lastFeed: p.lastFeed, next: p.next, intervalMinutes: Int((p.interval / 60).rounded()))
    }

    static func sync(babyName: String?, prediction: FeedSchedule.Prediction?, now: Date = Date()) {
        let current = Activity<NextFeedAttributes>.activities
        guard isEnabled, ActivityAuthorizationInfo().areActivitiesEnabled,
              let babyName, let state = contentState(for: prediction, now: now) else {
            endAll(current)
            return
        }
        // 예상 시각이 지나면 "오래된 정보"로 표시되도록 staleDate 지정
        let content = ActivityContent(state: state, staleDate: state.next)
        if let activity = current.first(where: { $0.attributes.babyName == babyName }) {
            guard activity.content.state != state else { return }
            Task { await activity.update(content) }
            endAll(current.filter { $0.id != activity.id })
        } else {
            endAll(current)
            _ = try? Activity.request(attributes: NextFeedAttributes(babyName: babyName), content: content)
        }
    }

    static func endAll(_ activities: [Activity<NextFeedAttributes>] = Activity<NextFeedAttributes>.activities) {
        for activity in activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}

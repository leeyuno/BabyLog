//
//  FeedReminder.swift
//  BabyLog
//
//  Created by 이윤오 on 2026/11/18.
//
//  다음 수유 알림 (앱 타깃 전용). 설정 탭에서 켠 경우에만 동작한다.
//  - 예상 시각(FeedSchedule) − 미리 알림 분 에 로컬 알림 1건만 예약 (항상 기존 예약을 지우고 다시)
//  - 다시 예약하는 시점: 기록 저장/삭제(saveAndRefreshWidgets), 앱 활성화, 설정 변경
//  - 예측이 없거나(수유 3회 미만) 이미 지난 시각이면 예약하지 않는다
//  - 같은 시점에 잠금화면 라이브 액티비티(NextFeedLiveActivity)도 갱신한다 (알림 설정과 별개)
//

import CoreData
import Foundation
import UserNotifications

enum FeedReminder {
    static let enabledKey = "reminder.nextFeed.enabled"
    static let leadMinutesKey = "reminder.nextFeed.leadMinutes"
    static let leadOptions = [0, 10, 20]
    private static let requestId = "babylog.next-feed"

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }
    static var leadMinutes: Int { UserDefaults.standard.integer(forKey: leadMinutesKey) }

    /// 알림 권한 요청. 거부되면 false.
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [requestId])
    }

    /// 알림 시각 계산 (순수 로직 — 테스트 대상). 지금보다 1분 이상 뒤일 때만.
    static func fireDate(prediction: FeedSchedule.Prediction?, leadMinutes: Int, now: Date = Date()) -> Date? {
        guard let p = prediction else { return nil }
        let fire = p.next.addingTimeInterval(-Double(leadMinutes) * 60)
        return fire.timeIntervalSince(now) >= 60 ? fire : nil
    }

    static func reschedule(context: NSManagedObjectContext, now: Date = Date()) {
        cancel()
        let baby = SharedPersistence.firstBaby(in: context)
        let prediction = baby.flatMap { FeedSchedule.prediction(for: $0, in: context, now: now) }
        NextFeedLiveActivity.sync(babyName: baby?.name, prediction: prediction, now: now)

        guard isEnabled, let baby, let p = prediction,
              let fire = fireDate(prediction: p, leadMinutes: leadMinutes, now: now) else { return }

        let content = UNMutableNotificationContent()
        content.title = leadMinutes == 0 ? "\(baby.name) 수유 시간이에요" : "\(leadMinutes)분 뒤 \(baby.name) 수유 예정"
        content.body = "마지막 수유 \(p.lastFeed.formatted(date: .omitted, time: .shortened)) · "
            + "평균 \(FeedSchedule.intervalText(p.interval)) 간격"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fire.timeIntervalSince(now), repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: requestId, content: content,
                                                                     trigger: trigger))
    }
}

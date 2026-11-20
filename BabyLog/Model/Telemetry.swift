//
//  Telemetry.swift
//  BabyLog
//
//  Created by 이윤오 on 2026/11/20.
//
//  크래시 리포트(Crashlytics) · 사용 통계(Analytics) 래퍼 (앱 타깃 전용). Android lib/platform/telemetry.dart 와 같은 이벤트.
//
//  원칙
//   - DEBUG 빌드에서는 수집하지 않는다 — 개발 데이터가 통계에 섞이지 않도록
//   - GoogleService-Info.plist 가 없어 Firebase 를 설정하지 않았으면 모든 호출이 아무 일도 하지 않는다
//   - ⚠️ 아기 이름·수유량·몸무게·메모 등 건강/개인 정보는 절대 보내지 않는다. 기능 사용(종류·횟수)만.
//   - 위젯 익스텐션에는 넣지 않았다 (위젯 크래시는 수집되지 않음)
//

import FirebaseAnalytics
import FirebaseCrashlytics
import Foundation

enum Telemetry {
    private(set) static var isEnabled = false

    /// FirebaseApp.configure() 직후 호출
    static func start() {
        isEnabled = true
        #if DEBUG
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
        Analytics.setAnalyticsCollectionEnabled(false)
        #else
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        Analytics.setAnalyticsCollectionEnabled(true)
        #endif
    }

    /// 기능 사용 이벤트. params 에는 종류 같은 범주 값만 (개인·건강 정보 금지)
    static func log(_ event: Event, _ params: [String: String] = [:]) {
        guard isEnabled else { return }
        Analytics.logEvent(event.rawValue, parameters: params.isEmpty ? nil : params)
    }

    /// 앱을 멈추지 않는 오류(동기화 실패 등)도 남긴다
    static func record(_ error: Error, reason: String) {
        guard isEnabled else { return }
        Crashlytics.crashlytics().log(reason)
        Crashlytics.crashlytics().record(error: error)
    }

    /// 이벤트 이름 (Android 와 동일)
    enum Event: String {
        case recordSaved = "record_saved"     // kind: feed|diaper|sleep, mode: new|edit
        case familyCreated = "family_created"
        case familyJoined = "family_joined"
        case familyLeft = "family_left"
        case backupExported = "backup_exported"
        case backupRestored = "backup_restored"
        case weightSaved = "weight_saved"
    }
}

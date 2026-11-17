//
//  FeedingGuide.swift
//  BabyLog
//
//  Created by 이윤오 on 2026/11/16.
//
//  수유량 자동 추천 (앱 타깃 전용, 순수 로직 — 단위 테스트 대상).
//
//  가이드(일반 소아과 공식, 분유 기준 참고값):
//    1일 총 수유량 = 체중(kg) × 150 ml, 최대 1,000 ml
//    1회 권장량   = 1일 총량 ÷ 개월수별 하루 수유 횟수 → 10 ml 단위 반올림
//    하루 횟수    : 0개월 8회 · 1개월 7회 · 2~3개월 6회 · 4~5개월 5회 · 6개월 이상 4회(이유식 병행)
//  ⚠️ 의료 조언이 아닌 참고값이다. UI 에 항상 "참고용" 안내를 함께 표시할 것.
//
//  기본값 규칙(자동추천 ON):
//    최근 평균 수유량(최근 5회) < 권장량  → 기본값 = 권장량
//    그 외                               → 기본값 = 직전 수유량 (자동추천 OFF 와 동일)
//    기록이 전혀 없으면                   → 권장량
//

import Foundation
import CoreData

/// 사용자 설정 키 (UserDefaults.standard / @AppStorage)
enum FeedingSettings {
    /// 수유량 자동 추천 on/off. 기본값 false(수동 = 직전 값 유지)
    static let autoRecommendKey = "feeding.autoRecommend"
}

enum FeedingGuide {
    static let mlPerKgPerDay = 150.0
    static let maxDailyML = 1000.0
    /// AddEventView Stepper 범위와 동일
    static let amountRange = 10...300
    static let roundingUnit = 10
    /// 기록이 없고 추천도 불가할 때의 기본값
    static let fallbackML = 60
    /// "최근 평균" 계산에 쓰는 수유 기록 수
    static let recentSampleCount = 5

    /// 개월수별 하루 수유 횟수
    static func feedsPerDay(ageMonths: Int) -> Int {
        switch ageMonths {
        case ..<1:   return 8
        case 1:      return 7
        case 2...3:  return 6
        case 4...5:  return 5
        default:     return 4
        }
    }

    /// 1일 권장 총량(ml). 체중이 0 이하면 nil.
    static func recommendedDailyML(weightKg: Double) -> Double? {
        guard weightKg > 0 else { return nil }
        return min(weightKg * mlPerKgPerDay, maxDailyML)
    }

    /// 1회 권장량(ml), 10ml 단위 반올림 후 입력 범위로 보정. 체중·개월수 중 하나라도 없으면 nil.
    static func recommendedPerFeedML(weightKg: Double, ageMonths: Int?) -> Int? {
        guard let months = ageMonths, months >= 0,
              let daily = recommendedDailyML(weightKg: weightKg) else { return nil }
        let raw = daily / Double(feedsPerDay(ageMonths: months))
        let rounded = Int((raw / Double(roundingUnit)).rounded()) * roundingUnit
        return clamp(rounded)
    }

    /// AddEventView 의 수유량 기본값을 결정한다. (규칙은 파일 상단 주석 참고)
    static func defaultFeedAmount(lastML: Int?,
                                  recentAverageML: Double?,
                                  recommendedML: Int?,
                                  autoRecommend: Bool) -> Int {
        let manual = clamp(lastML ?? fallbackML)
        guard autoRecommend, let rec = recommendedML else { return manual }
        guard let avg = recentAverageML else { return rec }     // 기록 없음 → 권장량
        return avg < Double(rec) ? rec : manual
    }

    /// 생일 기준 만 개월수
    static func ageInMonths(birthday: Date, now: Date = Date(), calendar: Calendar = .current) -> Int {
        max(calendar.dateComponents([.month], from: birthday, to: now).month ?? 0, 0)
    }

    static func clamp(_ ml: Int) -> Int {
        min(max(ml, amountRange.lowerBound), amountRange.upperBound)
    }
}

extension Baby {
    /// 개월수: 생일이 있으면 자동 계산, 없으면 설정에서 직접 입력한 값(manualAgeMonths ≥ 0). 둘 다 없으면 nil.
    var ageInMonths: Int? {
        if let birthday { return FeedingGuide.ageInMonths(birthday: birthday) }
        return manualAgeMonths >= 0 ? Int(manualAgeMonths) : nil
    }

    /// 현재 프로필 기준 1회 권장 수유량. 체중/개월수 미입력 시 nil.
    var recommendedPerFeedML: Int? {
        FeedingGuide.recommendedPerFeedML(weightKg: weightKg, ageMonths: ageInMonths)
    }
}

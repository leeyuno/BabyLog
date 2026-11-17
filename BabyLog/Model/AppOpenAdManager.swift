//
//  AppOpenAdManager.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/23.
//
//  앱 오프닝(전면) 광고 관리자.
//
//  흐름: BabyLogApp(scenePhase == .active) → onBecameActive() → 0.3초 후 showIfEligible()
//        → 정책 통과 시 (캐시된 광고 표시 | 로드 후 표시) → 닫히면 기록 후 다음 광고 프리로드
//
//  노출 정책(isEligibleNow): 육아 앱 특성상 보수적으로 유지한다.
//    1) 정오~다음날 정오 창마다 최대 1회
//    2) 조용시간(00~05시) 미노출 — 새벽 수유 중 방해 금지
//    3) 쿨다운, 콜드스타트 전용, 샘플링 옵션 (AppOpenRules)
//    4) 외부 차단 조건(shouldShowAd) — 예: 기록 입력 시트가 열려 있을 때
//

import Foundation
import GoogleMobileAds
import SwiftUI

/// 앱 오프닝 광고 노출 규칙
struct AppOpenRules {
    var enabled: Bool = true                 // 전체 온오프
    var onlyOnColdStart: Bool = false        // 콜드 스타트에서만 (백→포 전환은 미표시)
    var cooldownSec: TimeInterval = 20*60    // 마지막 노출 이후 쿨다운
    var minActiveSecAfterLaunch: TimeInterval = 0.2 // .active 후 최소 대기
    var sampling: Double = 1.0               // 0.0~1.0 확률 노출 (예: 0.5 = 50%)
}

final class AppOpenAdManager: NSObject, GADFullScreenContentDelegate {
    static let shared = AppOpenAdManager()

    /// 구글 정책상 앱 오프닝 광고는 로드 후 4시간이 지나면 만료된다.
    private static let adExpiry: TimeInterval = 4 * 60 * 60
    /// 표시할 VC 가 준비되지 않았을 때 재시도 횟수 상한(무한 루프 방지)
    private static let maxPresentRetries = 5

    private var ad: GADAppOpenAd?
    private var adLoadedAt: Date?
    private var isLoading = false
    /// 로드 중에 표시 요청이 들어오면 로드 완료 즉시 표시하기 위한 플래그
    private var presentWhenLoaded = false
    private var isShowing = false
    private weak var window: UIWindow?

    // 규칙 / 상태
    var rules = AppOpenRules()
    /// 외부 차단 조건 주입 (온보딩/편집 중/유료 광고제거 등). false 면 미노출.
    var shouldShowAd: (() -> Bool)? = { true }
    private var becameActiveAt: Date?
    private var coldStart = true
    private var shownAt: Date? {
        get { UserDefaults.standard.object(forKey: AdsConfig.kAppOpenLastShownAt) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: AdsConfig.kAppOpenLastShownAt) }
    }

    /// WindowAccessor 가 호출해 표시 기준 윈도우를 캐시한다(없어도 keyWindow 로 폴백).
    func attach(window: UIWindow) { self.window = window }

    /// scenePhase 가 .active 가 될 때 호출
    func onBecameActive() {
        becameActiveAt = Date()
    }

    /// 정책을 통과하면 광고를 표시(없으면 로드 후 표시)한다.
    func showIfEligible() {
        defer { coldStart = false }   // 첫 시도 이후엔 콜드스타트 아님
        guard !isShowing, isEligibleNow() else { return }

        if let ad = ad, !isExpired {
            present(ad: ad)
        } else {
            ad = nil
            loadAd(thenPresent: true)
        }
    }

    /// 표시 없이 프리로드만
    func preload() { loadAd(thenPresent: false) }

    private var isExpired: Bool {
        guard let loadedAt = adLoadedAt else { return true }
        return Date().timeIntervalSince(loadedAt) > Self.adExpiry
    }

    // MARK: - 정오~정오 1회 정책

    /// 현재 시각이 속한 "정오 창"의 시작(오늘 12시 이후면 오늘 정오, 아니면 어제 정오)
    private func currentNoonAnchor(now: Date = Date()) -> Date {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: now)
        guard let todayNoon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: startOfDay) else {
            return startOfDay
        }
        if now >= todayNoon { return todayNoon }
        return cal.date(byAdding: .day, value: -1, to: todayNoon) ?? todayNoon
    }

    private func lastShownAnchor() -> Date? {
        let ts = UserDefaults.standard.double(forKey: AdsConfig.kAppOpenLastAnchorTs)
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    private func markShownForCurrentWindow() {
        UserDefaults.standard.set(currentNoonAnchor().timeIntervalSince1970, forKey: AdsConfig.kAppOpenLastAnchorTs)
    }

    private func hasShownInCurrentWindow() -> Bool {
        guard let last = lastShownAnchor() else { return false }
        return abs(last.timeIntervalSince1970 - currentNoonAnchor().timeIntervalSince1970) < 0.5
    }

    private func isQuietHours(now: Date = Date()) -> Bool {
        guard AdsConfig.enableQuietHours else { return false }
        return AdsConfig.quietHourRange.contains(Calendar.current.component(.hour, from: now))
    }

    // MARK: - 표시 가능 여부

    private func isEligibleNow(now: Date = Date()) -> Bool {
        if AdsConfig.bypassAppOpenRules { return true }   // DEBUG 전용 우회 스위치

        guard rules.enabled else { return false }
        guard shouldShowAd?() ?? true else { return false }
        guard !isQuietHours(now: now) else { return false }
        guard !hasShownInCurrentWindow() else { return false }
        if rules.onlyOnColdStart && !coldStart { return false }
        if let last = shownAt, now.timeIntervalSince(last) < rules.cooldownSec { return false }
        if let active = becameActiveAt, now.timeIntervalSince(active) < rules.minActiveSecAfterLaunch {
            return false
        }
        if rules.sampling < 1.0, Double.random(in: 0...1) > rules.sampling { return false }
        return true
    }

    // MARK: - Load / Present

    private func loadAd(thenPresent: Bool) {
        if thenPresent { presentWhenLoaded = true }
        guard !isLoading else { return }   // 프리로드 진행 중이면 그 결과를 기다린다
        isLoading = true
        GADAppOpenAd.load(withAdUnitID: AdsConfig.appOpenUnitID, request: GADRequest()) { [weak self] ad, error in
            guard let self = self else { return }
            self.isLoading = false
            if let error = error {
                self.presentWhenLoaded = false
                print("❌ AppOpen load error:", error.localizedDescription)
                return
            }
            guard let ad = ad else { self.presentWhenLoaded = false; return }
            ad.fullScreenContentDelegate = self
            self.ad = ad
            self.adLoadedAt = Date()
            if self.presentWhenLoaded {
                self.presentWhenLoaded = false
                self.present(ad: ad)
            }
        }
    }

    /// 최상단 VC 가 준비될 때까지 0.3초 간격으로 최대 `maxPresentRetries`회 재시도.
    /// (다른 시트가 떠 있으면 결국 포기 — 사용자의 입력을 가로막지 않는다)
    private func present(ad: GADAppOpenAd, attempt: Int = 0) {
        DispatchQueue.main.async {
            guard !self.isShowing else { return }
            guard let root = self.topViewController(), root.presentedViewController == nil else {
                guard attempt < Self.maxPresentRetries else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    guard let self = self, let ad = self.ad else { return }
                    self.present(ad: ad, attempt: attempt + 1)
                }
                return
            }
            self.isShowing = true
            ad.present(fromRootViewController: root)
        }
    }

    private func topViewController() -> UIViewController? {
        let base = window?.rootViewController ?? {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first(where: { $0.activationState == .foregroundActive })?
                .windows.first(where: { $0.isKeyWindow })?
                .rootViewController
        }()
        return Self.findTop(from: base)
    }

    private static func findTop(from vc: UIViewController?) -> UIViewController? {
        guard let vc = vc else { return nil }
        if let nav = vc as? UINavigationController { return findTop(from: nav.visibleViewController) }
        if let tab = vc as? UITabBarController { return findTop(from: tab.selectedViewController) }
        if let p = vc.presentedViewController { return findTop(from: p) }
        return vc
    }

    // MARK: - GADFullScreenContentDelegate

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        isShowing = false
        shownAt = Date()               // 쿨다운용
        markShownForCurrentWindow()    // 정오~정오 1회 정책 기록
        self.ad = nil
        // 다음 노출을 위해 프리로드
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in self?.preload() }
    }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("❌ AppOpen present error:", error.localizedDescription)
        isShowing = false
        self.ad = nil
    }
}

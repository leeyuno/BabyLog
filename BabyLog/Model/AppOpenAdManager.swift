//
//  AppOpenAdManager.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/23.
//

import Foundation
import GoogleMobileAds
import SwiftUI

// 규칙 세트
struct AppOpenRules {
    var enabled: Bool = true                 // 전체 온오프
    var onlyOnColdStart: Bool = false        // 콜드 스타트에서만 (백→전환은 미표시)
    var cooldownSec: TimeInterval = 20*60    // 마지막 노출 이후 쿨다운
    var minActiveSecAfterLaunch: TimeInterval = 1.0 // .active 후 최소 대기
    var sampling: Double = 1.0               // 0.0~1.0 중 확률 노출 (예: 0.5 = 50%)
}

final class AppOpenAdManager: NSObject, GADFullScreenContentDelegate {
    static let shared = AppOpenAdManager()
    
    // 기존 프로퍼티 ...
    private var ad: GADAppOpenAd?
    private var isLoading = false
    private var isShowing = false
    private weak var window: UIWindow?
    
    // 🔧 규칙 / 상태
    var rules = AppOpenRules()
    var shouldShowAd: (() -> Bool)? = { true }      // 외부 조건 주입 (온보딩/편집/유료제거 등)
    private var becameActiveAt: Date?
    private var shownAt: Date? {
        get { UserDefaults.standard.object(forKey: "appopen.lastShownAt") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "appopen.lastShownAt") }
    }
    private var coldStart = true
    
    func attach(window: UIWindow) { self.window = window }
    
    // App이 active 될 때 호출
    func onBecameActive() {
        becameActiveAt = Date()
        // 앱 최초 1회만 true, 이후 포그라운드 전환에서는 false
        // 필요하면 외부에서 coldStart=false로 바꿔도 됨
    }
    
    // 외부에서 "표시 시도" 호출
    func showIfEligible() {
        print(isEligibleNow())
        guard isEligibleNow() else { return }
        print("showIfEligible")
        print("ad: \(ad)")
        if let ad = ad {
            present(ad: ad)
        } else {
            loadAd(thenPresent: true)
        }
        
        // 첫 시도 후에는 콜드스타트 플래그 해제
        coldStart = false
    }
    
    // 프리로드만
    func preload() { loadAd(thenPresent: false) }
    
    // --- 기존의 정오 앵커/quiet hours 함수들은 그대로 사용한다고 가정 ---
    private func currentNoonAnchor(now: Date = Date()) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        
        let startOfDay = cal.startOfDay(for: now)
        let todayNoon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: startOfDay)!
        if now >= todayNoon {
            return todayNoon
        } else {
            return cal.date(byAdding: .day, value: -1, to: todayNoon)!
        }
    }
    
    private func lastShownAnchor() -> Date? {
        let ts = UserDefaults.standard.double(forKey: AdsConfig.kAppOpenLastAnchorTs)
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }
    
    private func markShownForCurrentWindow() {
        let anchor = currentNoonAnchor()
        UserDefaults.standard.set(anchor.timeIntervalSince1970, forKey: AdsConfig.kAppOpenLastAnchorTs)
    }
    
    private func hasShownInCurrentWindow() -> Bool {
        guard let last = lastShownAnchor() else { return false }
        // 같은 앵커(= 같은 정오-정오 창)면 이미 노출
        return abs(last.timeIntervalSince1970 - currentNoonAnchor().timeIntervalSince1970) < 0.5
    }
    
    private func isQuietHours(now: Date = Date()) -> Bool {
        guard AdsConfig.enableQuietHours else { return false }
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .current
        let hour = cal.component(.hour, from: now)
        return AdsConfig.quietHourRange.contains(hour)
    }
    
    // ✅ 표시 가능성 판정
    private func isEligibleNow(now: Date = Date()) -> Bool {
        return true
//        guard rules.enabled else { return false }
//        guard shouldShowAd?() ?? true else { return false }
//        // 조용시간/정오~정오 1회 정책 (네가 이미 가진 함수)
//        guard !isQuietHours() else { return false }
//        guard !hasShownInCurrentWindow() else { return false }
//
//        // 콜드 스타트 옵션
//        if rules.onlyOnColdStart && !coldStart { return false }
//
//        // 쿨다운
//        if let last = shownAt, now.timeIntervalSince(last) < rules.cooldownSec { return false }
//
//        // .active 후 최소 대기
//        if let active = becameActiveAt, now.timeIntervalSince(active) < rules.minActiveSecAfterLaunch {
//            return false
//        }
//
//        // 샘플링(확률 노출)
//        if rules.sampling < 1.0 {
//            if Double.random(in: 0...1) > rules.sampling { return false }
//        }
        return true
    }
    
    // MARK: - Load / Present (이전 답변의 안정화 버전 사용 권장)
    private func loadAd(thenPresent: Bool) {
        print("loadAD\(thenPresent)")
        print(isLoading)
        guard !isLoading else { return }
        isLoading = true
        let req = GADRequest()
        GADAppOpenAd.load(withAdUnitID: AdsConfig.appOpenUnitID,
                          request: req
        ) { [weak self] ad, error in
            guard let self = self else { return }
            self.isLoading = false
            if let error = error {
                print("❌ AppOpen load error:", error.localizedDescription)
                return
            }
            guard let ad = ad else { print("❌ AppOpen no fill"); return }
            self.ad = ad
            ad.fullScreenContentDelegate = self
            print("✅ AppOpen loaded")
            print(thenPresent)
            if thenPresent { self.present(ad: ad) }
        }
    }
    
    private func present(ad: GADAppOpenAd) {
        print("####")
        print(ad)
        print(self.topViewController())
        print("###")
        DispatchQueue.main.async {
            guard let root = self.topViewController(),
                  root.presentedViewController == nil else {
                // 루트가 아직 없으면 약간 지연
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    if let ad = self?.ad { self?.present(ad: ad) }
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
    
    // MARK: - Delegate
    func adWillPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) { print("🔔 AppOpen will present") }
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("🔔 AppOpen dismissed")
        isShowing = false
        shownAt = Date()               // ✅ 쿨다운용 타임스탬프
        markShownForCurrentWindow()    // ✅ 정오~정오 1회 정책 기록(네 함수)
        self.ad = nil
        // 다음을 위해 프리로드
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in self?.preload() }
    }
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("❌ AppOpen present error:", error.localizedDescription)
        isShowing = false
        self.ad = nil
    }
}

////
////  AppOpenAdManager.swift
////  BabyLog
////
////  Created by 이윤오 on 2025/09/23.
////
//
//import Foundation
//import GoogleMobileAds
//import UIKit
//
//final class AppOpenAdManager: NSObject, GADFullScreenContentDelegate {
//    static let shared = AppOpenAdManager()
//
//    private var ad: GADAppOpenAd?
//    private var isLoading = false
//    private var isShowing = false
//
//    // 오늘 이미 노출했는지 확인
//    private func hasShownToday() -> Bool {
//        let last = UserDefaults.standard.string(forKey: AdsConfig.kAppOpenLastShown)
//        let today = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
//        return last == today
//    }
//    private func markShownToday() {
//        let today = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
//        UserDefaults.standard.set(today, forKey: AdsConfig.kAppOpenLastShown)
//    }
//
//    // 외부에서 호출: 포그라운드 될 때 적합
//    func showIfEligible() {
//        guard !isShowing, !isLoading else { return }
//        guard !hasShownToday() else { return } // 하루 1회 제한
//
//        if let ad = ad {
//            present(ad: ad)
//        } else {
//            loadAd { [weak self] in
//                guard let self = self, let ad = self.ad else { return }
//                self.present(ad: ad)
//            }
//        }
//    }
//
//    private func loadAd(completion: (() -> Void)? = nil) {
//        guard !isLoading else { return }
//        isLoading = true
//        GADAppOpenAd.load(withAdUnitID: AdsConfig.appOpenUnitID,
//                          request: GADRequest(),
//                          orientation: .portrait) { [weak self] ad, error in
//            guard let self = self else { return }
//            self.isLoading = false
//            if let ad = ad {
//                self.ad = ad
//                self.ad?.fullScreenContentDelegate = self
//                completion?()
//            } else {
//                // 실패 시 이후에 다시 시도 (쿨다운을 두고 재시도 추천)
//                DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
//                    self.ad = nil
//                }
//            }
//        }
//    }
//
//    private func present(ad: GADAppOpenAd) {
//        guard let root = UIApplication.shared
//            .connectedScenes
//            .compactMap({ $0 as? UIWindowScene })
//            .flatMap({ $0.windows })
//            .first(where: { $0.isKeyWindow })?
//            .rootViewController else { return }
//
//        isShowing = true
//        ad.present(fromRootViewController: root)
//    }
//
//    // MARK: - GADFullScreenContentDelegate
//    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
//        isShowing = false
//        markShownToday()           // 오늘 노출 완료 기록
//        self.ad = nil             // 다음 날을 위해 메모리 정리
//        // (옵션) 다음 사용을 위해 사전 로드
//        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
//            self?.loadAd()
//        }
//    }
//    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
//        isShowing = false
//        self.ad = nil
//    }
//}
//
//struct AppOpenAdHook: ViewModifier {
//    @Environment(\.scenePhase) private var scenePhase
//    func body(content: Content) -> some View {
//        content
//            .onChange(of: scenePhase) { phase in
//                if phase == .active {
//                    AppOpenAdManager.shared.showIfEligible()
//                }
//            }
//            .onAppear {
//                // cold start에서도 한 번 시도
//                AppOpenAdManager.shared.showIfEligible()
//            }
//    }
//}
//
//extension View {
//    func withAppOpenAd() -> some View { self.modifier(AppOpenAdHook()) }
//}

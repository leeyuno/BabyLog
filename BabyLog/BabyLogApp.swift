//
//  BabyLogApp.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/11.
//
//  앱 진입점.
//  - Core Data viewContext 와 Router 를 환경으로 주입
//  - babylog:// 딥링크(위젯 탭) → Router
//  - 앱 활성화 시: 위젯 원탭 기록 병합 + 다음 수유 알림 재예약
//  - 스토어를 열지 못하면(디스크 부족 등) 크래시 대신 안내 화면(StoreErrorView)
//

import SwiftUI

@main
struct BabyLogApp: App {
    @StateObject private var router = Router()
    let persistenceController = PersistenceController.shared

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            if let error = persistenceController.loadError {
                StoreErrorView(error: error)
            } else {
                RootView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .environmentObject(router)
                    .nightMode()   // 22~6시: 다크 + 따뜻한 강조색 + 큰 글씨 (설정에서 변경)
                    .onOpenURL { url in
                        router.handle(url: url)
                    }
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active, persistenceController.loadError == nil {
                // 앱이 쉬는 동안 위젯(원탭 기록)이 쓴 변경을 반영
                persistenceController.historyMerger?.mergeRemoteChanges()
                FeedReminder.reschedule(context: persistenceController.container.viewContext)
            }
        }
    }
}

/// 기록 저장소를 열지 못했을 때의 안내 화면. 기록 파일은 지우지 않으므로 원인을 해결하면 다시 열린다.
private struct StoreErrorView: View {
    let error: Error

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("기록을 불러오지 못했어요")
                .font(.title2.bold())
            Text("""
                저장된 기록은 지워지지 않았어요.
                휴대폰 저장 공간을 확보한 뒤 앱을 완전히 종료하고 다시 열어 주세요.
                문제가 계속되면 설정 > 앱 정보의 문의처로 알려 주세요.
                """)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .onAppear { Telemetry.record(error, reason: "store load") }
    }
}

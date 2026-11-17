//
//  RootView.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/11.
//
//  루트 화면: 아기가 없으면 온보딩, 있으면 [타임라인 | 주간 개요 | 설정] 탭.
//  Router.route 를 관찰해 딥링크 기반 "새 기록" 시트를 띄운다.
//

import SwiftUI
import CoreData

struct RootView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var router: Router

    @FetchRequest(
        fetchRequest: {
            let r = NSFetchRequest<Baby>(entityName: "Baby")               // ✅ 이름으로 명시
            r.sortDescriptors = [NSSortDescriptor(key: #keyPath(Baby.name), ascending: true)]  // ✅ keyPath 안전
            return r
        }(),
        animation: .default
    )
    private var babies: FetchedResults<Baby>

    @State private var showAdd = false
    @State private var addKind: AddKind = .feeding

    var body: some View {
        Group {
            if let baby = babies.first {
                TabView {
                    TimelineView(baby: baby)
                        .tabItem {
                            Image(systemName: "list.bullet.rectangle")
                            Text("타임라인")
                        }

                    WeeklyOverviewView(baby: baby)
                        .tabItem {
                            Image(systemName: "chart.bar.doc.horizontal")
                            Text("주간 개요")
                        }

                    SettingsView(baby: baby)
                        .tabItem {
                            Image(systemName: "gearshape")
                            Text("설정")
                        }
                }
                .sheet(
                    isPresented: $showAdd,
                    onDismiss: { router.reset() },
                    content: {
                        AddEventView(baby: baby, kind: CareKind(from: addKind))
                            .environment(\.managedObjectContext, context)
                    }
                )
                // 첫 진입(앱이 딥링크로 콜드스타트)에도 반영되도록 onAppear 에서도 확인
                .onAppear { presentIfNeeded(router.route) }
                .onChange(of: router.route) { route in
                    presentIfNeeded(route)
                }
                // 표시 기준 윈도우를 광고 매니저에 전달
                .background(WindowAccessor())
            } else {
                OnboardingNewBabyView()
            }
        }
    }

    private func presentIfNeeded(_ route: AppRoute) {
        if case .add(let k) = route {
            addKind = k
            showAdd = true
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        // 프리뷰에서도 라우터 주입 필요
        RootView()
            .environment(\.managedObjectContext, PreviewPersistence.controller.container.viewContext)
            .environmentObject(Router())
    }
}

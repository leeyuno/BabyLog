//
//  RootView.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/11.
//
//  루트 화면: 아기가 없으면 온보딩, 있으면 [타임라인 | 주간 개요 | 성장 | 설정] 탭.
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

                    GrowthView(baby: baby)
                        .tabItem {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                            Text("성장")
                        }

                    SettingsView(baby: baby)
                        .tabItem {
                            Image(systemName: "gearshape")
                            Text("설정")
                        }
                }
                // 백업 복원 등으로 아기 객체가 바뀌면 탭 전체를 새로 만든다 (지워진 객체 참조 방지)
                .id(baby.objectID)
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

//
//  RootView.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/11.
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
    @State private var addKind: AddKind = .sleep
    
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
                }
                .sheet(isPresented: $showAdd, onDismiss: { router.reset() }) {
                    AddEventView(baby: baby, kind: CareKind(from: addKind))
                            .environment(\.managedObjectContext, context)
                }
                .onChange(of: router.route) { route in
                    if case .add(let k) = route {
                        addKind = k
                        showAdd = true
                    }
                }
            } else {
                OnboardingNewBabyView()
            }
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        // 프리뷰에서도 라우터 주입 필요
        RootView()
//            .withAppOpenAd()
            .environmentObject(Router())
    }
}

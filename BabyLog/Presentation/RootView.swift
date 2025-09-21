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
    
    @FetchRequest(
        fetchRequest: {
            let r = NSFetchRequest<Baby>(entityName: "Baby")               // ✅ 이름으로 명시
            r.sortDescriptors = [NSSortDescriptor(key: #keyPath(Baby.name), ascending: true)]  // ✅ keyPath 안전
            return r
        }(),
        animation: .default
    )
    
    private var babies: FetchedResults<Baby>
    
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
            } else {
                OnboardingNewBabyView()
            }
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}

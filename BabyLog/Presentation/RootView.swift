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
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Baby.name, ascending: true)])
    private var babies: FetchedResults<Baby>
    
    var body: some View {
        Group {
            if let baby = babies.first {
                TimelineView(baby: baby)
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

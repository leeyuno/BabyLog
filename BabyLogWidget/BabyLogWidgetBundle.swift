//
//  BabyLogWidgetBundle.swift
//  BabyLogWidget
//
//  Created by 이윤오 on 2025/09/21.
//

import WidgetKit
import SwiftUI

@main
struct BabyLogWidgetBundle: WidgetBundle {
    var body: some Widget {
        BabyLogElapsedWidget()
        BabyLogTodayWidget()
        BabyLogDailySummaryWidget()
    }
}

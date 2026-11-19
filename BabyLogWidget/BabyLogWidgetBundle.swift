//
//  BabyLogWidgetBundle.swift
//  BabyLogWidget
//
//  Created by 이윤오 on 2025/09/21.
//
//  위젯 익스텐션 진입점 + 위젯 공용 유틸.
//  데이터는 App Group 의 Core Data 스토어를 SharedPersistence 로 직접 읽는다(DailySummary.swift).
//  앱이 저장 시 WidgetCenter.reloadAllTimelines() 를 호출하므로 즉시 갱신된다.
//

import WidgetKit
import SwiftUI

@main
struct BabyLogWidgetBundle: WidgetBundle {
    var body: some Widget {
        BabyLogElapsedWidget()
        BabyLogTodayWidget()
        BabyLogDailySummaryWidget()
        AddQuickRecordWidget()
        if #available(iOS 17.0, *) {
            BabyLogOneTapWidget()   // 인터랙티브 위젯(원탭 기록)은 iOS 17+
        }
        // BabyLogWidgetLiveActivity() — Xcode 템플릿 상태(미구현)라 번들에 포함하지 않음
    }
}

// 위젯 공용 배경 modifier `.widgetBackground()` 는 BabyLogQuickAddWIdget.swift 에 있다
// (위젯 파일들이 앱 타깃에도 컴파일되므로 양쪽 타깃에 포함된 파일에 둬야 함).

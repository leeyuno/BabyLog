//
//  NextFeedAttributes.swift
//  BabyLog
//
//  Created by 이윤오 on 2026/11/19.
//
//  잠금화면 "다음 수유" 라이브 액티비티의 데이터 정의.
//  ⚠️ 앱(시작·갱신: NextFeedLiveActivity)과 위젯(표시: BabyLogWidgetLiveActivity.swift) 두 타깃에 포함된다.
//     두 타깃이 같은 타입을 써야 하므로 필드를 바꾸면 양쪽이 함께 바뀐다.
//

import ActivityKit
import Foundation

struct NextFeedAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// 마지막 수유(묶음의 시작) 시각
        var lastFeed: Date
        /// 다음 수유 예상 시각
        var next: Date
        /// 평균 간격(분) — "평균 3시간 간격" 표시용
        var intervalMinutes: Int
    }

    var babyName: String
}

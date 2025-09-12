//
//  EmptyStateView.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/12.
//

import SwiftUI

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let message: String?
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
            Text(title).font(.title3).bold()
            if let message = message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
    }
}

struct EmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 1) 기본 (메시지 포함)
            EmptyStateView(
                title: "기록 없음",
                systemImage: "calendar.badge.exclamationmark",
                message: "오른쪽 위 + 버튼으로 첫 기록을 추가하세요."
            )
            .previewDisplayName("기본 - 라이트")

            // 2) 다크 모드
            EmptyStateView(
                title: "기록 없음",
                systemImage: "calendar.badge.exclamationmark",
                message: "오른쪽 위 + 버튼으로 첫 기록을 추가하세요."
            )
            .preferredColorScheme(.dark)
            .previewDisplayName("기본 - 다크")

            // 3) 메시지 없이 타이틀만
            EmptyStateView(
                title: "아직 데이터가 없어요",
                systemImage: "tray",
                message: nil
            )
            .previewDisplayName("메시지 없음")

            // 4) 긴 문구(줄바꿈/멀티라인 확인)
            EmptyStateView(
                title: "최근 이벤트가 없습니다",
                systemImage: "clock.badge.questionmark",
                message: "최근 24시간 내 기록이 없어요. 수유, 기저귀, 수면 중 하나를 추가하면 여기 타임라인에 표시됩니다. 상단의 + 버튼을 눌러 첫 기록을 시작해보세요."
            )
            .previewDisplayName("긴 문구")
        }
        .previewLayout(.sizeThatFits)
        .padding()
        .background(Color(.systemBackground))
    }
}

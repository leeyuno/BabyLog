//
//  BabyAvatarView.swift
//  BabyLog
//
//  Created by 이윤오 on 2026/11/18.
//
//  아기 프로필 사진(원형). 사진이 없으면 새벽달 톤 배경에 이름 첫 글자.
//  BabyPhotoStore 를 구독하므로 사진을 바꾸면 모든 화면에서 바로 갱신된다.
//

import SwiftUI

struct BabyAvatarView: View {
    @ObservedObject var baby: Baby
    var size: CGFloat = 40
    @ObservedObject private var photos = BabyPhotoStore.shared

    var body: some View {
        Group {
            if let image = photos.image(for: baby.id) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [Color(red: 0.18, green: 0.22, blue: 0.50),
                                            Color(red: 0.09, green: 0.11, blue: 0.27)],
                                   startPoint: .top, endPoint: .bottom)
                    Text(String(baby.name.prefix(1)))
                        .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 1.0, green: 0.89, blue: 0.63))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityLabel("\(baby.name) 프로필 사진")
    }
}

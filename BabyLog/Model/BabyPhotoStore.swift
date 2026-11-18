//
//  BabyPhotoStore.swift
//  BabyLog
//
//  Created by 이윤오 on 2026/11/18.
//
//  아기 프로필 사진 저장소 (앱 타깃 전용).
//  - Core Data 가 아닌 파일로 저장: App Group 컨테이너/BabyPhotos/<babyId>.jpg
//    (스키마 변경 없이 추가 가능, 나중에 위젯에서도 읽을 수 있음)
//  - 저장 시 가운데를 정사각형으로 잘라 600px JPEG 로 줄인다 (원본 수 MB → 수십 KB)
//  - 화면은 @ObservedObject BabyPhotoStore.shared 를 구독하면 사진 변경 시 갱신된다.
//

import SwiftUI
import UIKit

final class BabyPhotoStore: ObservableObject {
    static let shared = BabyPhotoStore()

    static let pixelSize: CGFloat = 600
    static let jpegQuality: CGFloat = 0.85

    /// 변경 알림용 (값 자체는 의미 없음)
    @Published private(set) var revision = 0
    private var cache: [UUID: UIImage] = [:]

    private var directory: URL? {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: BabyLogGroup.appGroupId)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let dir = base?.appendingPathComponent("BabyPhotos", isDirectory: true) else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func url(for id: UUID) -> URL? {
        directory?.appendingPathComponent("\(id.uuidString).jpg")
    }

    func image(for id: UUID) -> UIImage? {
        if let cached = cache[id] { return cached }
        guard let url = url(for: id), let image = UIImage(contentsOfFile: url.path) else { return nil }
        cache[id] = image
        return image
    }

    /// 원본 이미지 데이터(사진 보관함)를 정사각형 600px JPEG 로 저장
    func save(imageData: Data, for id: UUID) throws {
        guard let source = UIImage(data: imageData) else { throw PhotoError.unreadable }
        let square = Self.squareResized(source, side: Self.pixelSize)
        guard let jpeg = square.jpegData(compressionQuality: Self.jpegQuality), let url = url(for: id) else {
            throw PhotoError.writeFailed
        }
        try jpeg.write(to: url, options: .atomic)
        cache[id] = square
        revision += 1
    }

    func delete(for id: UUID) {
        if let url = url(for: id) { try? FileManager.default.removeItem(at: url) }
        cache[id] = nil
        revision += 1
    }

    /// 가운데 정사각형으로 잘라 side×side 로 그린다 (EXIF 회전은 UIImage.draw 가 반영)
    static func squareResized(_ image: UIImage, side: CGFloat) -> UIImage {
        let w = image.size.width, h = image.size.height
        let scale = side / min(w, h)
        let drawSize = CGSize(width: w * scale, height: h * scale)
        let origin = CGPoint(x: (side - drawSize.width) / 2, y: (side - drawSize.height) / 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }
    }

    enum PhotoError: LocalizedError {
        case unreadable, writeFailed
        var errorDescription: String? {
            switch self {
            case .unreadable: return "사진을 읽을 수 없습니다."
            case .writeFailed: return "사진을 저장하지 못했습니다."
            }
        }
    }
}

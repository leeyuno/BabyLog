//
//  BackupService.swift
//  BabyLog
//
//  Created by 이윤오 on 2026/11/18.
//
//  데이터 백업 / 복원 (앱 타깃 전용). 기기에만 저장되는 기록을 파일로 꺼내고 다시 넣는다.
//  ⚠️ 형식은 Android lib/data/backup.dart 와 완전히 같다 → 아이폰 ↔ 안드로이드 사이 이전도 가능.
//     필드를 바꾸면 양쪽을 함께 바꾸고 version 을 올릴 것.
//
//  형식 (JSON, 날짜는 epoch ms, enum 은 raw 정수, 값 없음은 null):
//    { "format": "babylog-backup", "version": 1, "exportedAt": ms, "platform": "ios",
//      "babies":  [{ id, name, birthday, weightKg, manualAgeMonths, sex, photoJpegBase64 }],
//      "events":  [{ id, babyId, kind, createdAt, feedType, feedAmountMl, diaperType,
//                    sleepStartAt, sleepEndAt, note, breastLeftSec, breastRightSec, breastLastSide }],
//      "weights": [{ id, babyId, measuredAt, weightKg }] }
//  복원은 "전체 교체": 현재 기록을 모두 지우고 백업 내용으로 바꾼다 (화면에서 한 번 더 확인).
//  ⚠️ ID 는 항상 소문자 UUID 문자열로 쓴다 (uuidString 은 대문자 → Android·Firestore 와 어긋나 중복 문서가 생김).
//     읽을 때는 대소문자 모두 허용. 가족 공유(FamilySync)도 같은 DTO·같은 규칙을 쓴다.
//

import CoreData
import SwiftUI
import UniformTypeIdentifiers

struct BackupPayload: Codable, Equatable {
    static let formatName = "babylog-backup"
    static let currentVersion = 1

    var format = formatName
    var version = currentVersion
    var exportedAt: Int64
    var platform = "ios"
    var babies: [BabyDTO]
    var events: [EventDTO]
    var weights: [WeightDTO]

    struct BabyDTO: Codable, Equatable {
        var id: String, name: String
        var birthday: Int64?
        var weightKg: Double, manualAgeMonths: Int, sex: Int
        var photoJpegBase64: String?
    }

    struct EventDTO: Codable, Equatable {
        var id: String, babyId: String
        var kind: Int, createdAt: Int64
        var feedType: Int?, feedAmountMl: Int, diaperType: Int?
        var sleepStartAt: Int64?, sleepEndAt: Int64?
        var note: String?
        var breastLeftSec: Int, breastRightSec: Int, breastLastSide: Int
    }

    struct WeightDTO: Codable, Equatable {
        var id: String, babyId: String
        var measuredAt: Int64, weightKg: Double
    }
}

enum BackupService {
    enum BackupError: LocalizedError {
        case notBabyLogFile, newerVersion(Int)
        var errorDescription: String? {
            switch self {
            case .notBabyLogFile: return "베이비로그 백업 파일이 아니에요."
            case .newerVersion(let v): return "더 새로운 버전(\(v))의 백업이에요. 앱을 업데이트한 뒤 다시 시도하세요."
            }
        }
    }

    struct Counts: Equatable { var babies = 0, events = 0, weights = 0 }

    /// 파일·서버에 쓰는 ID (소문자)
    static func wireID(_ id: UUID) -> String { id.uuidString.lowercased() }

    static func ms(_ date: Date) -> Int64 { Int64((date.timeIntervalSince1970 * 1000).rounded()) }
    static func date(_ ms: Int64) -> Date { Date(timeIntervalSince1970: Double(ms) / 1000) }

    // MARK: - 내보내기

    static func makePayload(context: NSManagedObjectContext, includePhotos: Bool = true,
                            now: Date = Date()) throws -> BackupPayload {
        let babies = try context.fetch(Baby.fetchRequest() as NSFetchRequest<Baby>)
        let events = try context.fetch(CareEvent.fetchRequest() as NSFetchRequest<CareEvent>)
        let weights = try context.fetch(WeightRecord.fetchRequest() as NSFetchRequest<WeightRecord>)
        return BackupPayload(
            exportedAt: ms(now),
            babies: babies.map { dto($0, includePhoto: includePhotos) },
            events: events.compactMap(dto),
            weights: weights.compactMap(dto)
        )
    }

    // MARK: - 객체 → DTO (백업·가족 공유 공용)

    static func dto(_ b: Baby, includePhoto: Bool = false) -> BackupPayload.BabyDTO {
        let photo = includePhoto
            ? BabyPhotoStore.shared.image(for: b.id)?.jpegData(compressionQuality: BabyPhotoStore.jpegQuality)
            : nil
        return .init(id: wireID(b.id), name: b.name, birthday: b.birthday.map(ms),
                     weightKg: b.weightKg, manualAgeMonths: Int(b.manualAgeMonths), sex: Int(b.sexRaw),
                     photoJpegBase64: photo?.base64EncodedString())
    }

    static func dto(_ e: CareEvent) -> BackupPayload.EventDTO? {
        // CareEvent.baby 는 Swift 선언상 non-optional 이지만 모델에서는 optional — 고아 기록은 제외
        guard let babyId = (e.value(forKey: "baby") as? Baby)?.id else { return nil }
        return .init(id: wireID(e.id), babyId: wireID(babyId), kind: Int(e.kindRaw),
                     createdAt: ms(e.createdAt), feedType: e.feedType.map { Int($0.rawValue) },
                     feedAmountMl: Int(e.feedAmountML), diaperType: e.diaperType.map { Int($0.rawValue) },
                     sleepStartAt: e.sleepStartAt.map(ms), sleepEndAt: e.sleepEndAt.map(ms), note: e.note,
                     breastLeftSec: Int(e.breastLeftSec), breastRightSec: Int(e.breastRightSec),
                     breastLastSide: Int(e.breastLastSide))
    }

    static func dto(_ w: WeightRecord) -> BackupPayload.WeightDTO? {
        guard let babyId = w.baby?.id else { return nil }
        return .init(id: wireID(w.id), babyId: wireID(babyId), measuredAt: ms(w.measuredAt), weightKg: w.weightKg)
    }

    // MARK: - DTO → 객체 (백업·가족 공유 공용)

    static func apply(_ dto: BackupPayload.BabyDTO, to b: Baby) {
        b.name = dto.name
        b.birthday = dto.birthday.map(date)
        b.weightKg = dto.weightKg
        b.manualAgeMonths = Int16(clamping: dto.manualAgeMonths)
        b.sexRaw = Int16(clamping: dto.sex)
    }

    static func apply(_ dto: BackupPayload.EventDTO, to e: CareEvent) {
        e.kindRaw = Int16(clamping: dto.kind)
        e.createdAt = date(dto.createdAt)
        e.feedTypeRaw = dto.feedType.map { Int16(clamping: $0) } ?? Int16.min
        e.feedAmountML = Int32(clamping: dto.feedAmountMl)
        e.diaperTypeRaw = dto.diaperType.map { Int16(clamping: $0) } ?? Int16.min
        e.sleepStartAt = dto.sleepStartAt.map(date)
        e.sleepEndAt = dto.sleepEndAt.map(date)
        e.note = dto.note
        e.breastLeftSec = Int32(clamping: dto.breastLeftSec)
        e.breastRightSec = Int32(clamping: dto.breastRightSec)
        e.breastLastSide = Int16(clamping: dto.breastLastSide)
    }

    static func apply(_ dto: BackupPayload.WeightDTO, to w: WeightRecord) {
        w.measuredAt = date(dto.measuredAt)
        w.weightKg = dto.weightKg
    }

    static func exportData(context: NSManagedObjectContext) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(makePayload(context: context))
    }

    // MARK: - 복원 (전체 교체)

    static func decode(_ data: Data) throws -> BackupPayload {
        guard let payload = try? JSONDecoder().decode(BackupPayload.self, from: data),
              payload.format == BackupPayload.formatName else { throw BackupError.notBabyLogFile }
        guard payload.version <= BackupPayload.currentVersion else { throw BackupError.newerVersion(payload.version) }
        return payload
    }

    /// 현재 데이터를 모두 지우고 백업으로 바꾼다. 저장(save)은 호출 측에서.
    @discardableResult
    static func replaceAll(with payload: BackupPayload, context: NSManagedObjectContext,
                           restorePhotos: Bool = true) throws -> Counts {
        for b in try context.fetch(Baby.fetchRequest() as NSFetchRequest<Baby>) {
            if restorePhotos { BabyPhotoStore.shared.delete(for: b.id) }
            context.delete(b)   // 기록·몸무게는 Cascade
        }
        var babies: [UUID: Baby] = [:]
        for dto in payload.babies {
            guard let id = UUID(uuidString: dto.id) else { continue }
            let b = Baby(context: context)
            b.id = id
            apply(dto, to: b)
            babies[id] = b
            if restorePhotos, let base64 = dto.photoJpegBase64, let data = Data(base64Encoded: base64) {
                try? BabyPhotoStore.shared.save(imageData: data, for: id)
            }
        }
        var counts = Counts(babies: babies.count)
        for dto in payload.events {
            guard let babyId = UUID(uuidString: dto.babyId), let baby = babies[babyId],
                  let id = UUID(uuidString: dto.id) else { continue }
            let e = CareEvent(context: context)
            e.id = id
            e.baby = baby
            apply(dto, to: e)
            counts.events += 1
        }
        for dto in payload.weights {
            guard let babyId = UUID(uuidString: dto.babyId), let baby = babies[babyId],
                  let id = UUID(uuidString: dto.id) else { continue }
            let w = WeightRecord(context: context)
            w.id = id
            w.baby = baby
            apply(dto, to: w)
            counts.weights += 1
        }
        return counts
    }
}

/// fileExporter 용 문서 (JSON)
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }

    static func defaultFilename(now: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "베이비로그-백업-\(f.string(from: now))"
    }
}

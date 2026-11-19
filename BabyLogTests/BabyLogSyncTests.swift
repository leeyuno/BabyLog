//
//  BabyLogSyncTests.swift
//  BabyLogTests
//
//  백업/복원과 가족 공유(FamilySync) 중 서버 없이 검증 가능한 부분.
//  (BabyLogTests 의 setUp·헬퍼를 그대로 쓰도록 extension 으로 둔다)
//

import CoreData
import XCTest
@testable import BabyLog

extension BabyLogTests {
    // MARK: - 백업 / 복원

    func testBackupRoundTrip() throws {
        baby.sex = .girl
        baby.birthday = Date(timeIntervalSince1970: 1_780_000_000)
        let feed = makeEvent(.feed, at: Date(timeIntervalSince1970: 1_790_000_000), ml: 120)
        feed.note = "잘 먹음"
        let breast = makeEvent(.feed, at: Date(timeIntervalSince1970: 1_790_003_600))
        breast.feedType = .breastMilk
        breast.breastLeftSec = 420
        breast.lastBreastSide = .left
        makeEvent(.diaper, at: Date(timeIntervalSince1970: 1_790_001_000), diaper: .poop)
        GrowthStore.upsert(weightKg: 6.3, on: Date(timeIntervalSince1970: 1_790_000_000), for: baby, in: context)

        let payload = try BackupService.makePayload(context: context, includePhotos: false)
        let data = try JSONEncoder().encode(payload)
        let decoded = try BackupService.decode(data)
        XCTAssertEqual(decoded, payload)

        // 다른(빈) 저장소에 복원
        let other = PersistenceController(inMemory: true).container.viewContext
        let counts = try BackupService.replaceAll(with: decoded, context: other, restorePhotos: false)
        XCTAssertEqual(counts, .init(babies: 1, events: 3, weights: 1))
        let again = try BackupService.makePayload(context: other, includePhotos: false,
                                                  now: Date(timeIntervalSince1970: Double(payload.exportedAt) / 1000))
        XCTAssertEqual(Set(again.events.map(\.id)), Set(payload.events.map(\.id)))
        XCTAssertEqual(again.babies, payload.babies)
        let restored = try XCTUnwrap(again.events.first { $0.id == BackupService.wireID(breast.id) })
        XCTAssertEqual(restored.breastLeftSec, 420)
        XCTAssertEqual(restored.feedAmountMl, 0)
        XCTAssertNil(again.events.first { $0.kind == Int(CareKind.diaper.rawValue) }?.feedType)
    }

    func testBackupRejectsForeignOrNewerFiles() {
        XCTAssertThrowsError(try BackupService.decode(Data("{}".utf8)))
        let json = #"{"format":"babylog-backup","version":99,"exportedAt":0,"platform":"android","#
            + #""babies":[],"events":[],"weights":[]}"#
        let newer = Data(json.utf8)
        XCTAssertThrowsError(try BackupService.decode(newer)) { error in
            XCTAssertEqual((error as? BackupService.BackupError)?.errorDescription,
                           BackupService.BackupError.newerVersion(99).errorDescription)
        }
    }

    // MARK: - 가족 공유 (FamilySync — 서버 없이 검증 가능한 부분)

    func testWireIDsAreLowercase() throws {
        let e = makeEvent(.feed, at: Date(), ml: 100)
        let dto = try XCTUnwrap(BackupService.dto(e))
        XCTAssertEqual(dto.id, dto.id.lowercased())
        XCTAssertEqual(dto.babyId, dto.babyId.lowercased())
        XCTAssertEqual(UUID(uuidString: dto.id), e.id)   // 읽을 때는 대소문자 무관
    }

    func testCollectChangesForFamilyPush() throws {
        try context.save()
        let e = makeEvent(.feed, at: Date(), ml: 90)
        GrowthStore.upsert(weightKg: 6.0, on: Date(), for: baby, in: context)
        var changes = FamilyChanges.collect(from: context)
        XCTAssertEqual(Set(changes.upserts.map(\.collection)), ["events", "weights", "babies"])  // 몸무게가 아기 정보도 바꿈
        try context.save()

        context.delete(e)
        changes = FamilyChanges.collect(from: context)
        XCTAssertEqual(changes.deletes.first?.collection, "events")
        XCTAssertEqual(changes.deletes.first?.id, BackupService.wireID(e.id))
    }

    func testApplyRemoteUpsertAndDelete() throws {
        try context.save()
        let babyId = BackupService.wireID(baby.id)
        // 안드로이드가 보낸 문서 (소문자 id, null 필드)
        let doc: [String: Any] = [
            "id": "0f1e2d3c-0000-4000-8000-0000000000a1", "babyId": babyId, "kind": 1, "createdAt": 1_795_000_000_000,
            "feedType": NSNull(), "feedAmountMl": 0, "diaperType": 1, "sleepStartAt": NSNull(), "sleepEndAt": NSNull(),
            "note": "묽음", "breastLeftSec": 0, "breastRightSec": 0, "breastLastSide": -1
        ]
        let docId = try XCTUnwrap(doc["id"] as? String)
        try FamilySync.applyRemote(RemoteChange(collection: "events", id: docId, data: doc), in: context)
        let req: NSFetchRequest<CareEvent> = CareEvent.fetchRequest()
        let e = try XCTUnwrap(try context.fetch(req).first)
        XCTAssertEqual(e.kind, .diaper)
        XCTAssertEqual(e.diaperType, .poop)
        XCTAssertNil(e.feedType)
        XCTAssertEqual(e.note, "묽음")

        // 같은 문서 수정 → 새로 만들지 않고 갱신
        var edited = doc
        edited["note"] = "보통"
        try FamilySync.applyRemote(RemoteChange(collection: "events", id: "0F1E2D3C-0000-4000-8000-0000000000A1",
                                                data: edited), in: context)
        XCTAssertEqual(try context.fetch(req).count, 1)
        XCTAssertEqual(try context.fetch(req).first?.note, "보통")

        // 삭제
        try FamilySync.applyRemote(RemoteChange(collection: "events", id: docId, data: nil), in: context)
        XCTAssertEqual(try context.fetch(req).count, 0)
    }
}

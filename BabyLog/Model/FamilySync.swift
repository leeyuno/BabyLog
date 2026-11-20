//
//  FamilySync.swift
//  BabyLog
//
//  Created by 이윤오 on 2026/11/19.
//
//  가족 공유 동기화 (앱 타깃 전용). Android lib/sync/family_sync.dart 와 같은 규칙.
//
//  - Core Data 가 기준. 사용자가 저장하면(saveAndRefreshWidgets) 바뀐 객체를 모아 서버로 보낸다(push).
//    Firestore SDK 의 오프라인 대기열 덕분에 인터넷이 없어도 나중에 전송된다.
//  - 위젯 원탭 기록(다른 프로세스)은 앱 활성화 때 PersistentHistoryMerger 가 찾아 보낸다.
//  - 다른 가족의 변경은 리스너로 받아 백그라운드 컨텍스트(author "family")에 반영 → viewContext 자동 병합.
//    원격 반영은 다시 보내지 않는다(되돌이 방지).
//  - 문서 형식 = 백업 DTO(BackupPayload.*DTO). ⚠️ ID 는 소문자 (BackupService.wireID)
//  - 만들기: 내 기록을 올린다 / 참여: 이 폰 기록을 가족 기록으로 "교체"(화면에서 확인) / 사진은 공유하지 않음
//  Firestore 구조·보안 규칙: firebase/firestore.rules
//

import CoreData
import Foundation
import WidgetKit

// MARK: - 서버 인터페이스 (실제 구현: FirestoreFamilyBackend)

struct FamilyDocs {
    var babies: [[String: Any]] = []
    var events: [[String: Any]] = []
    var weights: [[String: Any]] = []
}

struct RemoteChange {
    let collection: String      // "babies" | "events" | "weights"
    let id: String
    let data: [String: Any]?    // nil = 삭제
}

final class FamilyListener {
    private let onCancel: () -> Void
    init(onCancel: @escaping () -> Void) { self.onCancel = onCancel }
    func cancel() { onCancel() }
}

enum FamilyError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let m) = self { return m }; return nil }
}

protocol FamilyBackend: AnyObject {
    func signIn() async throws -> String
    func createFamily(_ initial: FamilyDocs) async throws -> String
    func createInvite(familyId: String) async throws -> String
    func join(code: String) async throws -> String
    func fetchAll(familyId: String) async throws -> FamilyDocs
    /// 다른 기기에서 생긴 변경 (내 기기가 보낸 쓰기는 제외). 처음 구독 시 현재 문서 전체가 한 번 온다.
    func watch(familyId: String, onChange: @escaping (RemoteChange) -> Void) -> FamilyListener
    func upsert(familyId: String, collection: String, doc: [String: Any]) async throws
    func delete(familyId: String, collection: String, id: String) async throws
    func memberCount(familyId: String) async throws -> Int
    func leave(familyId: String) async throws
}

// MARK: - DTO ↔ 문서(딕셔너리)

enum FamilyCodec {
    static func dict<T: Encodable>(_ value: T) -> [String: Any] {
        guard let data = try? JSONEncoder().encode(value),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return object
    }

    static func decode<T: Decodable>(_ type: T.Type, from dict: [String: Any]) -> T? {
        guard JSONSerialization.isValidJSONObject(dict),
              let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

/// 한 번의 저장에서 바뀐 것 (서버로 보낼 것)
struct FamilyChanges {
    var upserts: [(collection: String, doc: [String: Any])] = []
    var deletes: [(collection: String, id: String)] = []
    var isEmpty: Bool { upserts.isEmpty && deletes.isEmpty }

    /// 저장 "전"에 호출: 추가·수정·삭제될 기록/몸무게/아기를 모은다
    static func collect(from context: NSManagedObjectContext) -> FamilyChanges {
        var c = FamilyChanges()
        c.add(objects: Array(context.insertedObjects.union(context.updatedObjects)))
        for obj in context.deletedObjects {
            switch obj {
            case let e as CareEvent: c.deletes.append(("events", BackupService.wireID(e.id)))
            case let w as WeightRecord: c.deletes.append(("weights", BackupService.wireID(w.id)))
            default: break   // 아기 삭제(백업 복원)는 가족 공유 중에 막혀 있음
            }
        }
        return c
    }

    mutating func add(objects: [NSManagedObject]) {
        for obj in objects where !obj.isDeleted {
            switch obj {
            case let e as CareEvent:
                if let d = BackupService.dto(e) { upserts.append(("events", FamilyCodec.dict(d))) }
            case let w as WeightRecord:
                if let d = BackupService.dto(w) { upserts.append(("weights", FamilyCodec.dict(d))) }
            case let b as Baby:
                upserts.append(("babies", FamilyCodec.dict(BackupService.dto(b))))
            default: break
            }
        }
    }
}

// MARK: - 동기화

@MainActor
final class FamilySync: ObservableObject {
    static let shared = FamilySync()
    static let familyIdKey = "family.id"
    static let remoteAuthor = "family"

    /// nil = Firebase 미설정(설정 파일 없음) → 가족 공유 불가
    private(set) var backend: FamilyBackend?
    private var container: NSPersistentContainer?
    private var listener: FamilyListener?

    @Published private(set) var familyId: String? = UserDefaults.standard.string(forKey: familyIdKey)

    var isAvailable: Bool { backend != nil }
    var isJoined: Bool { familyId != nil }

    /// 앱 시작 시 (AppDelegate). 이미 가족이면 바로 수신 시작
    func configure(backend: FamilyBackend?, container: NSPersistentContainer) {
        self.backend = backend
        self.container = container
        if isJoined { start() }
    }

    private func setFamilyId(_ id: String?) {
        familyId = id
        UserDefaults.standard.set(id, forKey: Self.familyIdKey)
    }

    private func requireBackend() throws -> FamilyBackend {
        guard let backend else { throw FamilyError.message("지금은 가족 공유를 사용할 수 없어요.") }
        return backend
    }

    // MARK: 만들기 · 참여 · 나가기

    /// 가족 만들기: 내 기록을 올리고 초대 코드를 돌려준다
    func create() async throws -> String {
        let backend = try requireBackend()
        guard let context = container?.viewContext else { throw FamilyError.message("저장소가 준비되지 않았어요.") }
        _ = try await backend.signIn()
        let payload = try BackupService.makePayload(context: context, includePhotos: false)
        let docs = FamilyDocs(babies: payload.babies.map(FamilyCodec.dict),
                              events: payload.events.map(FamilyCodec.dict),
                              weights: payload.weights.map(FamilyCodec.dict))
        let id = try await backend.createFamily(docs)
        setFamilyId(id)
        start()
        Telemetry.log(.familyCreated)
        return try await backend.createInvite(familyId: id)
    }

    func newInvite() async throws -> String {
        let backend = try requireBackend()
        guard let id = familyId else { throw FamilyError.message("가족 공유 중이 아니에요.") }
        _ = try await backend.signIn()
        return try await backend.createInvite(familyId: id)
    }

    /// 초대 코드로 참여: 이 폰의 기록을 가족 기록으로 바꾼다
    func join(code: String) async throws {
        let backend = try requireBackend()
        guard let context = container?.viewContext else { throw FamilyError.message("저장소가 준비되지 않았어요.") }
        _ = try await backend.signIn()
        let id = try await backend.join(code: code.trimmingCharacters(in: .whitespaces).uppercased())
        let docs = try await backend.fetchAll(familyId: id)
        let payload = BackupPayload(
            exportedAt: BackupService.ms(Date()),
            babies: docs.babies.compactMap { FamilyCodec.decode(BackupPayload.BabyDTO.self, from: $0) },
            events: docs.events.compactMap { FamilyCodec.decode(BackupPayload.EventDTO.self, from: $0) },
            weights: docs.weights.compactMap { FamilyCodec.decode(BackupPayload.WeightDTO.self, from: $0) })
        try BackupService.replaceAll(with: payload, context: context, restorePhotos: false)
        try context.saveAndRefreshWidgets()   // 아직 familyId 가 없으므로 다시 보내지 않는다
        setFamilyId(id)
        start()
        Telemetry.log(.familyJoined)
    }

    func leave() async {
        stop()
        if let id = familyId, let backend {
            try? await backend.leave(familyId: id)   // 실패해도 이 폰에서는 나간 것으로
        }
        setFamilyId(nil)
        Telemetry.log(.familyLeft)
    }

    func memberCount() async -> Int {
        guard let id = familyId, let backend else { return 0 }
        return (try? await backend.memberCount(familyId: id)) ?? 0
    }

    // MARK: 수신

    func start() {
        guard listener == nil, let id = familyId, let backend, let container else { return }
        Task {
            _ = try? await backend.signIn()
            listener = backend.watch(familyId: id) { change in
                let context = container.newBackgroundContext()
                context.transactionAuthor = Self.remoteAuthor
                context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
                context.perform {
                    do {
                        try Self.applyRemote(change, in: context)
                        if context.hasChanges { try context.save() }   // 일반 save: 다시 보내지 않음
                    } catch {
                        print("[FamilySync] 반영 실패:", error)
                    }
                    Task { @MainActor in
                        WidgetCenter.shared.reloadAllTimelines()
                        FeedReminder.reschedule(context: container.viewContext)
                    }
                }
            }
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    /// 원격 변경 1건을 컨텍스트에 반영 (저장은 호출 측). 테스트 대상.
    nonisolated static func applyRemote(_ change: RemoteChange, in context: NSManagedObjectContext) throws {
        guard let id = UUID(uuidString: change.id) else { return }
        switch change.collection {
        case "babies":
            guard let data = change.data, let dto = FamilyCodec.decode(BackupPayload.BabyDTO.self, from: data) else {
                return   // 아기 삭제는 동기화하지 않음
            }
            let baby = try fetch(Baby.self, "Baby", id: id, in: context) ?? {
                let b = Baby(context: context)
                b.id = id
                return b
            }()
            BackupService.apply(dto, to: baby)
        case "events":
            let existing = try fetch(CareEvent.self, "CareEvent", id: id, in: context)
            guard let data = change.data else {
                existing.map(context.delete)
                return
            }
            guard let dto = FamilyCodec.decode(BackupPayload.EventDTO.self, from: data),
                  let babyId = UUID(uuidString: dto.babyId),
                  let baby = try fetch(Baby.self, "Baby", id: babyId, in: context) else { return }
            let e = existing ?? {
                let e = CareEvent(context: context)
                e.id = id
                return e
            }()
            e.baby = baby
            BackupService.apply(dto, to: e)
        case "weights":
            let existing = try fetch(WeightRecord.self, "WeightRecord", id: id, in: context)
            guard let data = change.data else {
                existing.map(context.delete)
                return
            }
            guard let dto = FamilyCodec.decode(BackupPayload.WeightDTO.self, from: data),
                  let babyId = UUID(uuidString: dto.babyId),
                  let baby = try fetch(Baby.self, "Baby", id: babyId, in: context) else { return }
            let w = existing ?? {
                let w = WeightRecord(context: context)
                w.id = id
                return w
            }()
            w.baby = baby
            BackupService.apply(dto, to: w)
        default:
            break
        }
    }

    private nonisolated static func fetch<T: NSManagedObject>(_ type: T.Type, _ entity: String, id: UUID,
                                                              in context: NSManagedObjectContext) throws -> T? {
        let req = NSFetchRequest<T>(entityName: entity)
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        req.fetchLimit = 1
        return try context.fetch(req).first
    }

    // MARK: 보내기

    func push(_ changes: FamilyChanges) {
        guard let id = familyId, let backend, !changes.isEmpty else { return }
        Task {
            for u in changes.upserts {
                do { try await backend.upsert(familyId: id, collection: u.collection, doc: u.doc) } catch {
                    print("[FamilySync] 전송 실패:", error)
                    Telemetry.record(error, reason: "family push")
                }
            }
            for d in changes.deletes {
                try? await backend.delete(familyId: id, collection: d.collection, id: d.id)
            }
        }
    }
}

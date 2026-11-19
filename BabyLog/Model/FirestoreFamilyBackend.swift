//
//  FirestoreFamilyBackend.swift
//  BabyLog
//
//  Created by 이윤오 on 2026/11/19.
//
//  가족 공유 — Firebase(익명 로그인 + Cloud Firestore) 구현 (앱 타깃 전용).
//  Android lib/platform/firebase_family_backend.dart 와 같은 동작. 보안 규칙: firebase/firestore.rules
//  - watch: 내 기기에서 아직 서버에 안 간 쓰기(hasPendingWrites)는 제외 → 되돌이 방지
//  ⚠️ GoogleService-Info.plist 는 공개 저장소라 커밋하지 않는다 (빌드 스크립트가 있을 때만 앱에 복사).
//

import FirebaseAuth
import FirebaseFirestore
import Foundation

final class FirestoreFamilyBackend: FamilyBackend {
    private let db = Firestore.firestore()
    private static let codeChars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")   // 0/O, 1/I 제외
    private static let inviteTTL: TimeInterval = 24 * 3600

    private func col(_ familyId: String, _ name: String) -> CollectionReference {
        db.collection("families").document(familyId).collection(name)
    }

    func signIn() async throws -> String {
        if let user = Auth.auth().currentUser { return user.uid }
        do {
            return try await Auth.auth().signInAnonymously().user.uid
        } catch let error as NSError {
            switch AuthErrorCode(rawValue: error.code) {
            case .operationNotAllowed:
                throw FamilyError.message("가족 공유 서버 준비가 아직 끝나지 않았어요. 잠시 후 다시 시도해 주세요.")
            case .networkError:
                throw FamilyError.message("인터넷 연결을 확인해 주세요.")
            default:
                throw FamilyError.message("로그인하지 못했어요. (\(error.code))")
            }
        }
    }

    func createFamily(_ initial: FamilyDocs) async throws -> String {
        let uid = try await signIn()
        let family = db.collection("families").document()
        // 규칙이 가족 문서로 구성원을 확인하므로 가족 문서를 먼저 만든 뒤 하위 문서를 올린다
        try await family.setData(["members": [uid], "createdBy": uid, "createdAt": FieldValue.serverTimestamp()])
        let docs = initial.babies.map { ("babies", $0) } + initial.events.map { ("events", $0) }
            + initial.weights.map { ("weights", $0) }
        for start in stride(from: 0, to: docs.count, by: 400) {   // 배치는 최대 500건
            let batch = db.batch()
            for (name, doc) in docs[start..<min(start + 400, docs.count)] {
                guard let id = doc["id"] as? String else { continue }
                batch.setData(doc, forDocument: col(family.documentID, name).document(id))
            }
            try await batch.commit()
        }
        return family.documentID
    }

    func createInvite(familyId: String) async throws -> String {
        let uid = try await signIn()
        let code = String((0..<6).map { _ in Self.codeChars[Int.random(in: 0..<Self.codeChars.count)] })
        try await db.collection("invites").document(code).setData([
            "familyId": familyId,
            "createdBy": uid,
            "expiresAt": Timestamp(date: Date().addingTimeInterval(Self.inviteTTL))
        ])
        return code
    }

    func join(code: String) async throws -> String {
        let uid = try await signIn()
        let invite = try await db.collection("invites").document(code).getDocument()
        guard let data = invite.data(), let familyId = data["familyId"] as? String,
              let expires = (data["expiresAt"] as? Timestamp)?.dateValue(), expires > Date() else {
            throw FamilyError.message("초대 코드가 없거나 만료됐어요. 새 코드를 받아 주세요.")
        }
        try await db.collection("families").document(familyId).updateData([
            "members": FieldValue.arrayUnion([uid]),
            "joinCode": code
        ])
        return familyId
    }

    func fetchAll(familyId: String) async throws -> FamilyDocs {
        func all(_ name: String) async throws -> [[String: Any]] {
            try await col(familyId, name).getDocuments().documents.map { $0.data() }
        }
        return FamilyDocs(babies: try await all("babies"), events: try await all("events"),
                          weights: try await all("weights"))
    }

    func watch(familyId: String, onChange: @escaping (RemoteChange) -> Void) -> FamilyListener {
        let registrations = ["babies", "events", "weights"].map { name in
            col(familyId, name).addSnapshotListener { snapshot, error in
                if let error { print("[Firestore] 수신 오류:", error) }
                for change in snapshot?.documentChanges ?? [] where !change.document.metadata.hasPendingWrites {
                    onChange(RemoteChange(collection: name, id: change.document.documentID,
                                          data: change.type == .removed ? nil : change.document.data()))
                }
            }
        }
        return FamilyListener { registrations.forEach { $0.remove() } }
    }

    func upsert(familyId: String, collection: String, doc: [String: Any]) async throws {
        guard let id = doc["id"] as? String else { return }
        try await col(familyId, collection).document(id).setData(doc)
    }

    func delete(familyId: String, collection: String, id: String) async throws {
        try await col(familyId, collection).document(id).delete()
    }

    func memberCount(familyId: String) async throws -> Int {
        let doc = try await db.collection("families").document(familyId).getDocument()
        return (doc.data()?["members"] as? [Any])?.count ?? 0
    }

    func leave(familyId: String) async throws {
        let uid = try await signIn()
        try await db.collection("families").document(familyId).updateData(["members": FieldValue.arrayRemove([uid])])
    }
}

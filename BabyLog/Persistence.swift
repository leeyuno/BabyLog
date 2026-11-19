//
//  Persistence.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/11.
//
//  앱 프로세스의 Core Data 스택. (앱 타깃 전용)
//  - 스토어는 App Group 컨테이너(BabyLogGroup.storeURL)에 위치 → 위젯이 같은 파일을 읽는다.
//  - 모델은 CoreDataModel.shared 하나만 사용(테스트/프리뷰에서 엔티티 중복 경고 방지).
//  - 저장은 가능한 한 `context.saveAndRefreshWidgets()`를 사용해 위젯을 즉시 갱신한다.
//  - 위젯(원탭 기록)이 같은 스토어에 쓰면 영속 히스토리로 viewContext 에 병합한다(PersistentHistoryMerger).
//

import CoreData
import WidgetKit

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer
    let historyMerger: PersistentHistoryMerger?

    /// - Parameter inMemory: true 면 /dev/null 스토어(프리뷰·유닛테스트용)
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "BabyLog", managedObjectModel: CoreDataModel.shared)

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            guard let storeURL = BabyLogGroup.storeURL else {
                // 앱 타깃은 App Group 엔타이틀먼트가 필수. 없으면 위젯과 데이터가 분리되므로 즉시 실패시킨다.
                fatalError("App Group(\(BabyLogGroup.appGroupId)) 컨테이너에 접근할 수 없습니다. 엔타이틀먼트를 확인하세요.")
            }
            container.persistentStoreDescriptions = [SharedPersistence.storeDescription(url: storeURL)]
        }

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                // 실패 원인: 디스크 부족, 잠금 상태의 데이터 보호, 마이그레이션 불가 등.
                // TODO: 출시 전 사용자 알림/복구 경로 마련 (현재는 개발 단계라 크래시로 노출)
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.transactionAuthor = PersistentHistoryMerger.appAuthor
        historyMerger = inMemory ? nil : PersistentHistoryMerger(container: container)
    }
}

/// 다른 프로세스(위젯 원탭 기록)가 스토어에 쓴 변경을 앱 화면(viewContext)에 반영한다.
/// - 원격 변경 알림(NSPersistentStoreRemoteChange) + 앱 활성화 시 mergeRemoteChanges() 호출
/// - 앱 자신이 쓴 트랜잭션(author = "app")은 건너뛴다
final class PersistentHistoryMerger {
    static let appAuthor = "app"

    private let container: NSPersistentContainer
    private var lastToken: NSPersistentHistoryToken?
    private let queue = DispatchQueue(label: "babylog.history")
    private var observer: NSObjectProtocol?

    init(container: NSPersistentContainer) {
        self.container = container
        // 시작 시점 이전 히스토리는 이미 스토어에서 읽었으므로 현재 위치부터
        lastToken = container.persistentStoreCoordinator.currentPersistentHistoryToken(fromStores: nil)
        observer = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange, object: container.persistentStoreCoordinator, queue: nil
        ) { [weak self] _ in self?.mergeRemoteChanges() }
    }

    deinit { observer.map(NotificationCenter.default.removeObserver) }

    func mergeRemoteChanges() {
        queue.async { [weak self] in
            guard let self else { return }
            let context = self.container.newBackgroundContext()
            context.performAndWait {
                let request = NSPersistentHistoryChangeRequest.fetchHistory(after: self.lastToken)
                guard let result = try? context.execute(request) as? NSPersistentHistoryResult,
                      let transactions = result.result as? [NSPersistentHistoryTransaction],
                      !transactions.isEmpty else { return }
                self.lastToken = transactions.last?.token
                let foreign = transactions.filter { $0.author != Self.appAuthor }
                guard !foreign.isEmpty else { return }
                let viewContext = self.container.viewContext
                viewContext.perform {
                    for tx in foreign { viewContext.mergeChanges(fromContextDidSave: tx.objectIDNotification()) }
                    FeedReminder.reschedule(context: viewContext)   // 위젯 기록도 다음 수유 예상에 반영
                }
            }
        }
    }
}

extension NSManagedObjectContext {
    /// 변경사항이 있으면 저장하고 위젯 타임라인을 새로고침한다.
    /// 실패 시 변경을 롤백하고 에러를 다시 던진다(호출 측에서 사용자 알림 처리).
    func saveAndRefreshWidgets() throws {
        guard hasChanges else { return }
        do {
            try save()
        } catch {
            rollback()
            throw error
        }
        WidgetCenter.shared.reloadAllTimelines()
        FeedReminder.reschedule(context: self)   // 수유 기록이 바뀌면 다음 수유 알림도 다시 예약
    }
}

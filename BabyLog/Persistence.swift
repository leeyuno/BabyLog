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
//

import CoreData
import WidgetKit

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

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
            container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: storeURL)]
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
    }
}

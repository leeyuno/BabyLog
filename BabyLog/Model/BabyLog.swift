//
//  BabyLog.swift (Baby 엔티티)
//  BabyLog
//
//  Created by 이윤오 on 2025/09/13.
//

import CoreData

/// 아기 프로필. 현재 UI는 첫 번째 아기(이름순)만 사용한다.
/// events 관계는 Cascade 삭제.
@objc(Baby)
public class Baby: NSManagedObject {}

extension Baby: Identifiable {}

extension Baby {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Baby> {
        NSFetchRequest<Baby>(entityName: "Baby")
    }

    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var birthday: Date?
    /// 체중(kg). 0 = 미입력. (모델 v2 에서 추가)
    @NSManaged public var weightKg: Double
    /// 생일이 없을 때 직접 입력한 개월수. -1 = 미입력. (모델 v2 에서 추가)
    @NSManaged public var manualAgeMonths: Int16
    /// 성별 raw (BabySex). 0 = 선택 안 함 (모델 v4)
    @NSManaged public var sexRaw: Int16
    @NSManaged public var events: Set<CareEvent>?
}

extension Baby {
    var sex: BabySex {
        get { BabySex(rawValue: sexRaw) ?? .unknown }
        set { sexRaw = newValue.rawValue }
    }
}

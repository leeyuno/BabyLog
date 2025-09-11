//
//  CoreDataClass.swift
//  BabyLog
//
//  Created by 이윤오 on 2025/09/11.
//

import CoreData

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
    @NSManaged public var events: Set<CareEvent>?
}


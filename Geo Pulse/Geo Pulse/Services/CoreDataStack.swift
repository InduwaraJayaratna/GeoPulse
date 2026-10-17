import Foundation
import CoreData

final class CoreDataStack {
    static let shared = CoreDataStack()

    let container: NSPersistentContainer

    private init() {
        let model = NSManagedObjectModel()

        let siteEntity = NSEntityDescription()
        siteEntity.name = "CDSite"
        siteEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        siteEntity.properties = [
            Self.attribute("id", .UUIDAttributeType),
            Self.attribute("name", .stringAttributeType),
            Self.attribute("latitude", .doubleAttributeType),
            Self.attribute("longitude", .doubleAttributeType),
            Self.attribute("radius", .doubleAttributeType)
        ]

        let taskEntity = NSEntityDescription()
        taskEntity.name = "CDTask"
        taskEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        taskEntity.properties = [
            Self.attribute("id", .UUIDAttributeType),
            Self.attribute("title", .stringAttributeType),
            Self.attribute("siteId", .UUIDAttributeType),
            Self.attribute("status", .stringAttributeType),
            Self.attribute("priority", .stringAttributeType),
            Self.attribute("scheduledAt", .dateAttributeType)
        ]

        let inspectionEntity = NSEntityDescription()
        inspectionEntity.name = "CDInspection"
        inspectionEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        inspectionEntity.properties = [
            Self.attribute("id", .UUIDAttributeType),
            Self.attribute("taskId", .UUIDAttributeType),
            Self.attribute("siteName", .stringAttributeType),
            Self.attribute("hazardTag", .stringAttributeType, optional: true),
            Self.attribute("hazardConfidence", .doubleAttributeType, optional: true),
            Self.attribute("voiceNote", .stringAttributeType, optional: true),
            Self.attribute("completedAt", .dateAttributeType),
            Self.attribute("syncState", .stringAttributeType)
        ]

        model.entities = [siteEntity, taskEntity, inspectionEntity]

        container = NSPersistentContainer(name: "GeoPulseStore", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSSQLiteStoreType
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        description.url = supportDir.appendingPathComponent("GeoPulseStore.sqlite")
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { _, _ in }
    }

    var viewContext: NSManagedObjectContext { container.viewContext }

    private static func attribute(_ name: String, _ type: NSAttributeType, optional: Bool = false) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        return attribute
    }
}

import Foundation
import CoreData

/// Programmatic Core Data stack for GeoPulse's offline-first inspection store.
///
/// We define the model in code so there's no `.xcdatamodeld` to maintain in the
/// project navigator. The store sits in Application Support and persists across
/// launches. `AppState` is the only consumer — it loads existing records on
/// init and writes new ones from `recordInspectionCompleted(_:)`.
final class CoreDataStack {
    static let shared = CoreDataStack()

    private let container: NSPersistentContainer
    private let inspectionEntityName = "CDInspection"

    private init() {
        let model = NSManagedObjectModel()
        let inspection = NSEntityDescription()
        inspection.name = "CDInspection"
        inspection.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        inspection.properties = [
            Self.attr("id", .UUIDAttributeType),
            Self.attr("taskId", .UUIDAttributeType),
            Self.attr("siteName", .stringAttributeType),
            Self.attr("inspectorName", .stringAttributeType),
            Self.attr("completedAt", .dateAttributeType),
            Self.attr("durationMinutes", .integer32AttributeType),
            Self.attr("resultSummary", .stringAttributeType),
            Self.attr("passedCount", .integer32AttributeType),
            Self.attr("totalCount", .integer32AttributeType),
            Self.attr("statusTag", .stringAttributeType),
            Self.attr("hazardTag", .stringAttributeType, optional: true),
            Self.attr("hazardConfidence", .doubleAttributeType, optional: true),
            Self.attr("voiceNote", .stringAttributeType, optional: true),
            Self.attr("photoName", .stringAttributeType, optional: true),
            Self.attr("syncStateRaw", .stringAttributeType)
        ]
        model.entities = [inspection]

        container = NSPersistentContainer(name: "GeoPulseStore", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSSQLiteStoreType
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        description.url = supportDir.appendingPathComponent("GeoPulseStore.sqlite")
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error { print("Core Data load failed: \(error)") }
        }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Inspection CRUD

    func saveInspection(_ inspection: Inspection) {
        let context = container.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: inspectionEntityName)
        request.predicate = NSPredicate(format: "id == %@", inspection.id as CVarArg)
        request.fetchLimit = 1

        let managed = (try? context.fetch(request).first)
            ?? NSEntityDescription.insertNewObject(forEntityName: inspectionEntityName, into: context)

        managed.setValue(inspection.id, forKey: "id")
        managed.setValue(inspection.taskId, forKey: "taskId")
        managed.setValue(inspection.siteName, forKey: "siteName")
        managed.setValue(inspection.inspectorName, forKey: "inspectorName")
        managed.setValue(inspection.completedAt, forKey: "completedAt")
        managed.setValue(Int32(inspection.durationMinutes), forKey: "durationMinutes")
        managed.setValue(inspection.resultSummary, forKey: "resultSummary")
        managed.setValue(Int32(inspection.passedCount), forKey: "passedCount")
        managed.setValue(Int32(inspection.totalCount), forKey: "totalCount")
        managed.setValue(inspection.statusTag, forKey: "statusTag")
        managed.setValue(inspection.hazardTag, forKey: "hazardTag")
        managed.setValue(inspection.hazardConfidence, forKey: "hazardConfidence")
        managed.setValue(inspection.voiceNote, forKey: "voiceNote")
        managed.setValue(inspection.photoName, forKey: "photoName")
        managed.setValue(Self.syncStateRaw(inspection.syncState), forKey: "syncStateRaw")

        try? context.save()
    }

    func fetchAllInspections() -> [Inspection] {
        let context = container.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: inspectionEntityName)
        request.sortDescriptors = [NSSortDescriptor(key: "completedAt", ascending: false)]
        guard let rows = try? context.fetch(request) else { return [] }
        return rows.compactMap(Self.toInspection)
    }

    // MARK: - Helpers

    private static func attr(_ name: String, _ type: NSAttributeType, optional: Bool = false) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        return attribute
    }

    private static func syncStateRaw(_ state: SyncState) -> String {
        switch state {
        case .savedLocally: return "savedLocally"
        case .syncedToTeam: return "syncedToTeam"
        case .syncing: return "syncing"
        }
    }

    private static func syncState(from raw: String?) -> SyncState {
        switch raw {
        case "syncedToTeam": return .syncedToTeam
        case "syncing": return .syncing
        default: return .savedLocally
        }
    }

    private static func toInspection(_ row: NSManagedObject) -> Inspection? {
        guard
            let id = row.value(forKey: "id") as? UUID,
            let taskId = row.value(forKey: "taskId") as? UUID,
            let siteName = row.value(forKey: "siteName") as? String,
            let inspectorName = row.value(forKey: "inspectorName") as? String,
            let completedAt = row.value(forKey: "completedAt") as? Date
        else { return nil }

        return Inspection(
            id: id,
            taskId: taskId,
            siteName: siteName,
            inspectorName: inspectorName,
            completedAt: completedAt,
            durationMinutes: Int((row.value(forKey: "durationMinutes") as? Int32) ?? 0),
            resultSummary: (row.value(forKey: "resultSummary") as? String) ?? "",
            passedCount: Int((row.value(forKey: "passedCount") as? Int32) ?? 0),
            totalCount: Int((row.value(forKey: "totalCount") as? Int32) ?? 0),
            statusTag: (row.value(forKey: "statusTag") as? String) ?? "Verified",
            hazardTag: row.value(forKey: "hazardTag") as? String,
            hazardConfidence: row.value(forKey: "hazardConfidence") as? Double,
            voiceNote: row.value(forKey: "voiceNote") as? String,
            photoName: row.value(forKey: "photoName") as? String,
            syncState: syncState(from: row.value(forKey: "syncStateRaw") as? String)
        )
    }
}

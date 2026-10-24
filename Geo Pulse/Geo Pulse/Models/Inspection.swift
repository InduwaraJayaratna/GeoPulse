import Foundation

struct Inspection: Identifiable, Hashable {
    let id: UUID
    var taskId: UUID
    var siteId: UUID?
    var siteName: String
    var inspectorName: String
    var completedAt: Date
    var durationMinutes: Int
    var resultSummary: String
    var passedCount: Int
    var totalCount: Int
    var statusTag: String
    var hazardTag: String?
    var hazardConfidence: Double?
    var voiceNote: String?
    var photoName: String?
    var syncState: SyncState

    init(
        id: UUID = UUID(),
        taskId: UUID,
        siteId: UUID? = nil,
        siteName: String,
        inspectorName: String,
        completedAt: Date = Date(),
        durationMinutes: Int = 0,
        resultSummary: String = "",
        passedCount: Int = 0,
        totalCount: Int = 0,
        statusTag: String = "Verified",
        hazardTag: String? = nil,
        hazardConfidence: Double? = nil,
        voiceNote: String? = nil,
        photoName: String? = nil,
        syncState: SyncState = .savedLocally
    ) {
        self.id = id
        self.taskId = taskId
        self.siteId = siteId
        self.siteName = siteName
        self.inspectorName = inspectorName
        self.completedAt = completedAt
        self.durationMinutes = durationMinutes
        self.resultSummary = resultSummary
        self.passedCount = passedCount
        self.totalCount = totalCount
        self.statusTag = statusTag
        self.hazardTag = hazardTag
        self.hazardConfidence = hazardConfidence
        self.voiceNote = voiceNote
        self.photoName = photoName
        self.syncState = syncState
    }
}

enum SyncState: Hashable {
    case savedLocally
    case syncedToTeam
    case syncing

    var displayText: String {
        switch self {
        case .savedLocally: return "Saved locally"
        case .syncedToTeam: return "Synced to team"
        case .syncing: return "Syncing..."
        }
    }

    var tone: BadgeTone {
        switch self {
        case .savedLocally: return .warning
        case .syncedToTeam: return .success
        case .syncing: return .info
        }
    }
}

struct HazardLog: Identifiable, Hashable {
    let id: UUID
    var siteName: String
    var hazardType: String
    var confidence: Double
    var note: String
    var loggedAt: Date
    var severity: HazardSeverity

    init(
        id: UUID = UUID(),
        siteName: String,
        hazardType: String,
        confidence: Double,
        note: String,
        loggedAt: Date = Date(),
        severity: HazardSeverity = .medium
    ) {
        self.id = id
        self.siteName = siteName
        self.hazardType = hazardType
        self.confidence = confidence
        self.note = note
        self.loggedAt = loggedAt
        self.severity = severity
    }
}

enum HazardSeverity: String, CaseIterable, Hashable {
    case low, medium, high

    var displayText: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    var tone: BadgeTone {
        switch self {
        case .low: return .info
        case .medium: return .warning
        case .high: return .danger
        }
    }
}

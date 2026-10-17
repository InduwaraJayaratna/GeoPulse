import Foundation

struct FieldTask: Identifiable, Hashable {
    let id: UUID
    var title: String
    var siteId: UUID
    var siteName: String
    var subLocation: String
    var dueDescription: String
    var protocolCode: String
    var ticketNumber: Int
    var priority: TaskPriority
    var status: TaskStatus
    var scheduledAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        siteId: UUID,
        siteName: String,
        subLocation: String,
        dueDescription: String,
        protocolCode: String = "ASTM-F1166",
        ticketNumber: Int,
        priority: TaskPriority = .normal,
        status: TaskStatus = .notStarted,
        scheduledAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.siteId = siteId
        self.siteName = siteName
        self.subLocation = subLocation
        self.dueDescription = dueDescription
        self.protocolCode = protocolCode
        self.ticketNumber = ticketNumber
        self.priority = priority
        self.status = status
        self.scheduledAt = scheduledAt
    }
}

enum TaskPriority: String, Hashable {
    case normal
    case attention
    case urgent

    var displayText: String {
        switch self {
        case .normal: return "Scheduled"
        case .attention: return "Attention needed"
        case .urgent: return "Critical window"
        }
    }

    var tone: BadgeTone {
        switch self {
        case .normal: return .info
        case .attention: return .warning
        case .urgent: return .danger
        }
    }
}

enum TaskStatus: String, Hashable {
    case notStarted
    case inProgress
    case completed
    case flagged

    var displayText: String {
        switch self {
        case .notStarted: return "Not Started"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .flagged: return "Flagged"
        }
    }
}

struct Checkpoint: Identifiable, Hashable {
    let id: UUID
    var index: Int
    var title: String
    var subtitle: String?
    var status: CheckpointStatus
    var noteSummary: String?

    init(
        id: UUID = UUID(),
        index: Int,
        title: String,
        subtitle: String? = nil,
        status: CheckpointStatus,
        noteSummary: String? = nil
    ) {
        self.id = id
        self.index = index
        self.title = title
        self.subtitle = subtitle
        self.status = status
        self.noteSummary = noteSummary
    }
}

enum CheckpointStatus: Hashable {
    case passed
    case flagged(String)
    case current
    case pending
    case remediated

    var displayText: String {
        switch self {
        case .passed: return "Passed"
        case .flagged(let reason): return reason
        case .current: return "Active"
        case .pending: return "Pending"
        case .remediated: return "Remediated"
        }
    }

    var tone: BadgeTone {
        switch self {
        case .passed: return .success
        case .flagged: return .warning
        case .current: return .info
        case .pending: return .neutral
        case .remediated: return .warning
        }
    }
}

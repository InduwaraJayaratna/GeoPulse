import Foundation

/// Abstraction over the team-sync backend.
///
/// GeoPulse's proposal names Firestore as the sync layer. In the MVP this is
/// implemented by `MockSyncRepository`, which demonstrates the architecture
/// (async-stream activity feed, publish/subscribe semantics, dependency
/// injection seam) without requiring a Firebase project to be configured.
/// Swapping in a real `FirestoreSyncRepository` later is a one-line change in
/// `AppState`.
protocol SyncRepository: AnyObject {
    /// Push a completed inspection to the team feed.
    func publish(inspection: Inspection) async

    /// Stream of events coming from the backend (manager assignments,
    /// peer inspection logs, safety alerts). Consumers should subscribe once
    /// at app launch and keep the task alive for the session.
    func activityFeed() -> AsyncStream<ActivityEvent>

    /// Latest connection status for sync-indicator UI.
    var connectionStatus: SyncConnectionStatus { get }
}

enum SyncConnectionStatus: String {
    case offline
    case connecting
    case live

    var displayText: String {
        switch self {
        case .offline: return "Offline"
        case .connecting: return "Connecting…"
        case .live: return "Live"
        }
    }
}

struct ActivityEvent: Identifiable, Hashable {
    enum Kind: String {
        case taskAssigned
        case inspectionLogged
        case hazardFlagged
        case fallAlert
    }

    let id: UUID
    let kind: Kind
    let actorName: String
    let siteName: String
    let summary: String
    let occurredAt: Date

    init(
        id: UUID = UUID(),
        kind: Kind,
        actorName: String,
        siteName: String,
        summary: String,
        occurredAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.actorName = actorName
        self.siteName = siteName
        self.summary = summary
        self.occurredAt = occurredAt
    }
}

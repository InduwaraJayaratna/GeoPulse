import Foundation

/// Local demonstration feed, not a remote delivery service. Buffers publications
/// while disconnected and replays recent events to new subscribers.
@MainActor
final class MockSyncRepository: SyncRepository {
    private(set) var connectionStatus: SyncConnectionStatus
    private var continuations: [UUID: AsyncStream<ActivityEvent>.Continuation] = [:]
    private var events: [ActivityEvent] = []
    private var pending: [Inspection] = []
    private var publishedIDs: Set<UUID> = []

    init(connected: Bool = true) {
        connectionStatus = connected ? .live : .offline
    }

    func connect() async {
        connectionStatus = .live
        let queued = pending
        pending.removeAll()
        for inspection in queued { await publish(inspection: inspection) }
    }

    func publish(inspection: Inspection) async {
        guard !publishedIDs.contains(inspection.id) else { return }
        guard connectionStatus == .live else {
            if !pending.contains(where: { $0.id == inspection.id }) { pending.append(inspection) }
            return
        }
        publishedIDs.insert(inspection.id)
        let event = ActivityEvent(
            kind: inspection.statusTag == "Safety incident" ? .fallAlert
                : (inspection.hazardTag == nil ? .inspectionLogged : .hazardFlagged),
            actorName: inspection.inspectorName,
            siteName: inspection.siteName,
            summary: inspection.hazardTag.map { "Flagged \($0)" } ?? inspection.resultSummary
        )
        events.append(event)
        if events.count > 40 { events.removeFirst() }
        for continuation in continuations.values { continuation.yield(event) }
    }

    func activityFeed() -> AsyncStream<ActivityEvent> {
        AsyncStream(bufferingPolicy: .bufferingNewest(40)) { continuation in
            let id = UUID()
            continuations[id] = continuation
            for event in events { continuation.yield(event) }
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in self?.continuations.removeValue(forKey: id) }
            }
        }
    }
}

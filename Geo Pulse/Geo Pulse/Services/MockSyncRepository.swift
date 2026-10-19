import Foundation

/// In-memory sync implementation used by the MVP.
///
/// Simulates a Firestore-style real-time stream: emits an initial burst of
/// seeded manager activity, then drip-feeds new events on a timer so the live
/// activity feed in the UI reacts without a real backend.
///
/// To swap in real Firestore:
/// 1. Follow `FirebaseSetup.md` to add the Firebase SDK + GoogleService-Info.plist
/// 2. Implement `FirestoreSyncRepository: SyncRepository` with Firestore queries
/// 3. Replace `MockSyncRepository()` with `FirestoreSyncRepository()` in `AppState`
final class MockSyncRepository: SyncRepository, @unchecked Sendable {
    private(set) var connectionStatus: SyncConnectionStatus = .connecting
    private var continuations: [UUID: AsyncStream<ActivityEvent>.Continuation] = [:]
    private let queueLock = NSLock()
    private var timer: Timer?

    init() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            self.connectionStatus = .live
            self.emitInitialBurst()
            self.startPeriodicEmits()
        }
    }

    deinit {
        timer?.invalidate()
    }

    func publish(inspection: Inspection) async {
        guard connectionStatus == .live else { return }
        let event = ActivityEvent(
            kind: inspection.hazardTag == nil ? .inspectionLogged : .hazardFlagged,
            actorName: inspection.inspectorName,
            siteName: inspection.siteName,
            summary: inspection.hazardTag.map { "Flagged \($0)" } ?? inspection.resultSummary
        )
        broadcast(event)
    }

    func activityFeed() -> AsyncStream<ActivityEvent> {
        AsyncStream { continuation in
            let id = UUID()
            queueLock.lock()
            continuations[id] = continuation
            queueLock.unlock()
            continuation.onTermination = { [weak self] _ in
                self?.queueLock.lock()
                self?.continuations.removeValue(forKey: id)
                self?.queueLock.unlock()
            }
        }
    }

    private func emitInitialBurst() {
        let seed: [ActivityEvent] = [
            ActivityEvent(
                kind: .taskAssigned,
                actorName: "Markus Vance",
                siteName: "Riverside Plant Sector 4",
                summary: "Assigned 3 pending inspections",
                occurredAt: Date().addingTimeInterval(-540)
            ),
            ActivityEvent(
                kind: .inspectionLogged,
                actorName: "Priya Sahu",
                siteName: "Harbor Loading Terminal",
                summary: "Completed 5 of 5 checkpoints",
                occurredAt: Date().addingTimeInterval(-300)
            ),
            ActivityEvent(
                kind: .hazardFlagged,
                actorName: "Devin Oyelaran",
                siteName: "Apex Industrial Complex",
                summary: "Flagged surface corrosion on auxiliary flange",
                occurredAt: Date().addingTimeInterval(-120)
            )
        ]
        for event in seed { broadcast(event) }
    }

    private func startPeriodicEmits() {
        timer = Timer.scheduledTimer(withTimeInterval: 45.0, repeats: true) { [weak self] _ in
            self?.emitRandomTeamEvent()
        }
    }

    private func emitRandomTeamEvent() {
        let pool: [ActivityEvent] = [
            ActivityEvent(
                kind: .taskAssigned,
                actorName: "Markus Vance",
                siteName: "Riverside Plant Sector 4",
                summary: "Re-prioritised Compressor Station 3 to urgent"
            ),
            ActivityEvent(
                kind: .inspectionLogged,
                actorName: "Priya Sahu",
                siteName: "South Reservoir",
                summary: "Noted elevated salinity, no action required"
            ),
            ActivityEvent(
                kind: .hazardFlagged,
                actorName: "Devin Oyelaran",
                siteName: "Harbor Loading Terminal",
                summary: "Logged hairline crack near Pier 2 strain gauge"
            )
        ]
        if let event = pool.randomElement() {
            broadcast(event)
        }
    }

    private func broadcast(_ event: ActivityEvent) {
        queueLock.lock()
        let snapshot = continuations
        queueLock.unlock()
        for continuation in snapshot.values {
            continuation.yield(event)
        }
    }
}

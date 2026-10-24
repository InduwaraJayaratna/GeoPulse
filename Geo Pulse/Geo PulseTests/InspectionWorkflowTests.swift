import Foundation
import Testing
@testable import Geo_Pulse

@MainActor
private final class MemoryStore: InspectionStore {
    var records: [Inspection] = []
    var failSave = false
    var failLoad = false
    var saves = 0
    func saveInspection(_ inspection: Inspection) throws {
        if failSave { throw CocoaError(.fileWriteNoPermission) }
        saves += 1
        records.removeAll { $0.id == inspection.id }
        records.append(inspection)
    }
    func fetchAllInspections() throws -> [Inspection] {
        if failLoad { throw CocoaError(.fileReadCorruptFile) }
        return records
    }
}

@MainActor
@Suite("Inspection workflow")
struct InspectionWorkflowTests {
    private let date = Date(timeIntervalSince1970: 10_000)
    private func draft() -> InspectionDraft {
        InspectionDraft(task: SampleData.tasks[1], voiceNote: "Measured on site",
            checkpoints: [Checkpoint(index: 1, title: "Condition", status: .passed)],
            startedAt: date.addingTimeInterval(-180))
    }

    @Test func completionPreservesEvidenceAndUpdatesCorrectTask() throws {
        let store = MemoryStore()
        let app = AppState(store: store, now: { date }, observeEvents: false)
        var draft = draft()
        draft.hazardTag = "Crack"; draft.hazardConfidence = 0.3; draft.photoName = "evidence.jpg"
        draft.checkpoints.append(Checkpoint(index: 2, title: "Damage", status: .flagged("Crack")))
        let result = try app.completeInspection(from: draft, certifies: true)
        #expect(result.id == draft.id)
        #expect(result.taskId == draft.task.id)
        #expect(result.siteId == draft.task.siteId)
        #expect(result.durationMinutes == 3)
        #expect(result.completedAt == date)
        #expect(result.passedCount == 1 && result.totalCount == 2)
        #expect(result.statusTag == "Conditional")
        #expect(result.hazardConfidence == 0.3)
        #expect(result.photoName == "evidence.jpg")
        #expect(result.voiceNote == "Measured on site")
        #expect(store.records == [result])
        #expect(app.sites[0].tasks[1].status == .completed)
        #expect(app.sites[0].tasks[0].status == .notStarted)
    }

    @Test func duplicateDraftIsSavedOnce() throws {
        let store = MemoryStore()
        let app = AppState(store: store, observeEvents: false)
        let draft = draft()
        let first = try app.completeInspection(from: draft, certifies: true)
        let second = try app.completeInspection(from: draft, certifies: true)
        #expect(first == second)
        #expect(store.saves == 1)
        #expect(app.inspectionHistory.count == 1)
    }

    @Test func failedSaveDoesNotCompleteTaskOrInsertHistory() {
        let store = MemoryStore(); store.failSave = true
        let app = AppState(store: store, observeEvents: false)
        #expect(throws: (any Error).self) { try app.completeInspection(from: draft(), certifies: true) }
        #expect(app.inspectionHistory.isEmpty)
        #expect(app.sites[0].tasks[1].status == .notStarted)
    }

    @Test func certificationAndCheckpointOutcomesAreRequired() {
        let store = MemoryStore()
        let app = AppState(store: store, observeEvents: false)
        #expect(throws: InspectionValidationError.self) { try app.completeInspection(from: draft(), certifies: false) }
        var incomplete = draft(); incomplete.checkpoints[0].status = .pending
        #expect(throws: InspectionValidationError.self) { try app.completeInspection(from: incomplete, certifies: true) }
        incomplete.checkpoints = []
        #expect(throws: InspectionValidationError.self) { try app.completeInspection(from: incomplete, certifies: true) }
        #expect(store.saves == 0)
    }

    @Test func cleanInspectionHasNoInventedEvidence() throws {
        let app = AppState(store: MemoryStore(), now: { date }, observeEvents: false)
        var draft = draft(); draft.voiceNote = nil; draft.startedAt = date.addingTimeInterval(10)
        let record = try app.completeInspection(from: draft, certifies: true)
        #expect(record.hazardTag == nil && record.hazardConfidence == nil)
        #expect(record.photoName == nil && record.voiceNote == nil)
        #expect(record.statusTag == "Verified")
        #expect(record.durationMinutes == 1)
    }

    @Test func reloadRestoresTaskCompletion() throws {
        let store = MemoryStore()
        let app = AppState(store: store, observeEvents: false)
        _ = try app.completeInspection(from: draft(), certifies: true)
        let reloaded = AppState(store: store, observeEvents: false)
        #expect(reloaded.sites[0].tasks[1].status == .completed)
        #expect(reloaded.inspectionHistory.count == 1)
    }

    @Test func loadFailureIsVisible() {
        let store = MemoryStore(); store.failLoad = true
        let app = AppState(store: store, observeEvents: false)
        #expect(app.errorMessage != nil)
        #expect(app.inspectionHistory.isEmpty)
    }

    @Test func appStateDoesNotRetainItselfThroughFeed() async {
        weak var reference: AppState?
        var app: AppState? = AppState(store: MemoryStore())
        reference = app
        app = nil
        await Task.yield()
        #expect(reference == nil)
    }
}

@MainActor
@Suite("Safety incident persistence")
struct SafetyIncidentTests {
    @Test func incidentIsSavedOnceAndDoesNotClaimDispatch() {
        let store = MemoryStore()
        let notifications = NotificationService(schedule: { _ in })
        let app = AppState(store: store, notificationService: notifications, observeEvents: false)
        app.showFallAlert = true
        app.escalateFallAlert()
        app.escalateFallAlert()
        #expect(store.saves == 1)
        #expect(!app.showFallAlert)
        #expect(store.records.first?.statusTag == "Safety incident")
        #expect(store.records.first?.syncState == .savedLocally)
        #expect(store.records.first?.resultSummary.contains("recorded locally") == true)
    }
    @Test func incidentSaveFailureIsVisible() {
        let store = MemoryStore(); store.failSave = true
        let app = AppState(store: store, notificationService: NotificationService(schedule: { _ in }), observeEvents: false)
        app.showFallAlert = true
        app.escalateFallAlert()
        #expect(app.errorMessage != nil)
        #expect(app.inspectionHistory.isEmpty)
    }
}

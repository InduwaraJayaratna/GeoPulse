import Foundation

/// Captured during the Inspect flow, consumed by `ReviewSignOffView` to build
/// a final `Inspection` on sign-off. Decouples the data-collection view
/// (InspectView) from the review view, which otherwise had no way to see the
/// hazard tag, voice note, or captured photo.
struct InspectionDraft: Identifiable, Hashable {
    var id: UUID = UUID()
    let task: FieldTask
    var hazardTag: String?
    var hazardConfidence: Double?
    var voiceNote: String?
    var photoName: String?
    var checkpoints: [Checkpoint] = []
    var startedAt: Date = Date()
}

enum InspectionValidationError: LocalizedError {
    case certificationRequired, incompleteCheckpoints
    var errorDescription: String? {
        switch self {
        case .certificationRequired: return "Confirm that the inspection reflects your observations before submitting."
        case .incompleteCheckpoints: return "Record an outcome for every checkpoint before submitting."
        }
    }
}

extension InspectionDraft {
    var isComplete: Bool {
        !checkpoints.isEmpty && checkpoints.allSatisfy {
            switch $0.status {
            case .passed, .flagged, .remediated: return true
            case .current, .pending: return false
            }
        }
    }
    var passedCount: Int {
        checkpoints.filter {
            switch $0.status { case .passed, .remediated: return true; default: return false }
        }.count
    }
    var hasFlaggedCheckpoint: Bool {
        checkpoints.contains { if case .flagged = $0.status { return true }; return false }
    }
}

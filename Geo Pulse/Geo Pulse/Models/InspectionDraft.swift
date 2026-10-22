import Foundation

/// Captured during the Inspect flow, consumed by `ReviewSignOffView` to build
/// a final `Inspection` on sign-off. Decouples the data-collection view
/// (InspectView) from the review view, which otherwise had no way to see the
/// hazard tag, voice note, or captured photo.
struct InspectionDraft: Identifiable, Hashable {
    let id: UUID = UUID()
    let task: FieldTask
    var hazardTag: String?
    var hazardConfidence: Double?
    var voiceNote: String?
    var photoName: String?
    var startedAt: Date = Date()
}

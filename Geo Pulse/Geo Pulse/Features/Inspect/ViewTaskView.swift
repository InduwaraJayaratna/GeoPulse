import SwiftUI

struct ViewTaskView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let task: FieldTask
    @State private var severity: HazardSeverity = .medium
    @State private var notes = ""
    @State private var errorMessage: String?
    @State private var recordID = UUID()

    var body: some View {
        Form {
            Section("Associated task") { Text(task.title); Text(task.siteName) }
            Section("Remediation finding") {
                Picker("Severity", selection: $severity) {
                    ForEach(HazardSeverity.allCases, id: \.self) { Text($0.displayText).tag($0) }
                }
                TextEditor(text: $notes).frame(minHeight: 120).accessibilityLabel("Remediation notes")
            }
            Section {
                Button("Save remediation record") {
                    let record = Inspection(id: recordID, taskId: task.id, siteId: task.siteId,
                        siteName: appState.sites.first { $0.id == task.siteId }?.name ?? task.siteName,
                        inspectorName: appState.currentUser.displayName,
                        resultSummary: "\(severity.displayText) severity remediation finding: \(notes)",
                        statusTag: "Remediation", hazardTag: "Remediation required", voiceNote: notes)
                    do { try appState.recordInspectionCompleted(record); dismiss() }
                    catch { errorMessage = error.localizedDescription }
                }.disabled(notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.navigationTitle("Remediation")
        .alert("Could not save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }
}

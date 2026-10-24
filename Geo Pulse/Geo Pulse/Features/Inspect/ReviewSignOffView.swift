import SwiftUI

struct ReviewSignOffView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let draft: InspectionDraft
    @State private var certifies = false
    @State private var submittedInspection: Inspection?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(draft.task.title).font(.title2.bold())
                Text("Inspector: \(appState.currentUser.displayName)")
                Text("\(draft.passedCount) of \(draft.checkpoints.count) checkpoints passed or remediated")
                ForEach(draft.checkpoints) { checkpoint in
                    VStack(alignment: .leading) {
                        Text(checkpoint.title).font(.headline)
                        Text(checkpoint.status.displayText)
                    }.accessibilityElement(children: .combine)
                }
                Divider()
                Text("Photo analysis").font(.headline)
                Text(draft.hazardTag ?? "No hazard suggestion recorded. This does not certify the site as safe.")
                Text("Notes").font(.headline)
                Text(draft.voiceNote ?? "No notes recorded.")
                Toggle("I certify that these records reflect my actual observations.", isOn: $certifies)
                Button("Sign and Submit Inspection", systemImage: "signature") {
                    do { submittedInspection = try appState.completeInspection(from: draft, certifies: certifies) }
                    catch { errorMessage = error.localizedDescription }
                }.buttonStyle(.borderedProminent).frame(minHeight: 44)
                    .disabled(!certifies || submittedInspection != nil)
            }.padding(20)
        }
        .navigationTitle("Review & Sign Off")
        .sheet(item: $submittedInspection, onDismiss: { dismiss() }) { inspection in
            NavigationStack { CertifiedReportView(inspection: inspection) }
        }
        .alert("Inspection not saved", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }
}

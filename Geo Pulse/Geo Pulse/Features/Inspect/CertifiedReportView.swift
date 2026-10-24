import SwiftUI

struct CertifiedReportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    let inspection: Inspection
    @State private var reportURL: URL?
    @State private var reportError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(inspection.siteName).font(.title2.bold())
                StatusBadge(text: inspection.statusTag, tone: inspection.statusTag == "Verified" ? .success : .warning)
                Text("Inspector: \(inspection.inspectorName)")
                Text(inspection.completedAt.formatted(date: .abbreviated, time: .shortened))
                Text("Duration: \(inspection.durationMinutes) minutes")
                Text("\(inspection.passedCount) of \(inspection.totalCount) checkpoints passed or remediated")
                Text(inspection.resultSummary)
                if let hazard = inspection.hazardTag { Text("Finding: \(hazard)").font(.headline) }
                if let note = inspection.voiceNote { Text(note) }
                if let name = inspection.photoName, let url = PhotoStore().url(for: name),
                   let image = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: image).resizable().scaledToFit()
                        .accessibilityLabel("Saved inspection photo")
                }
                Text(inspection.syncState.displayText).font(.caption)
                if let reportURL { ShareLink("Share PDF Report", item: reportURL).frame(minHeight: 44) }
                if let reportError { Text(reportError).foregroundStyle(.red) }
                Button("Done") { dismiss() }.frame(minHeight: 44)
            }.padding(20)
        }
        .navigationTitle("Inspection Report")
        .task {
            reportURL = PDFReportBuilder.build(for: inspection, user: appState.currentUser)
            if reportURL == nil { reportError = "Could not generate PDF. Your inspection remains saved." }
        }
    }
}

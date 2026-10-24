import SwiftUI
import PhotosUI

struct InspectView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var speech = SpeechService()
    var task: FieldTask? = nil
    @State private var notes = ""
    @State private var checkpoints: [Checkpoint] = []
    @State private var photoItem: PhotosPickerItem?
    @State private var capturedImage: UIImage?
    @State private var photoName: String?
    @State private var hazardResult: HazardClassificationResult?
    @State private var isAnalyzing = false
    @State private var showCamera = false
    @State private var pendingDraft: InspectionDraft?
    @State private var errorMessage: String?
    @State private var startedAt = Date()
    @State private var draftID = UUID()
    private var selectedTask: FieldTask? { task ?? appState.selectedTask ?? appState.todayTasks.first { $0.status != .completed } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let selectedTask {
                    Text(selectedTask.title).font(.title2.bold())
                    Text("Task #\(selectedTask.ticketNumber) · \(selectedTask.subLocation)").font(.subheadline)
                    Text("Record each checkpoint outcome. Only observed evidence will be saved.")
                        .foregroundStyle(.secondary)
                    ForEach($checkpoints) { $checkpoint in
                        VStack(alignment: .leading) {
                            Text(checkpoint.title).font(.headline)
                            Picker("Outcome for \(checkpoint.title)", selection: $checkpoint.status) {
                                Text("Not checked").tag(CheckpointStatus.pending)
                                Text("Passed").tag(CheckpointStatus.passed)
                                Text("Needs attention").tag(CheckpointStatus.flagged("Needs attention"))
                            }.pickerStyle(.menu)
                        }
                    }
                    Divider()
                    Text("Inspection notes").font(.headline)
                    TextEditor(text: $notes).frame(minHeight: 120)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary))
                        .accessibilityLabel("Inspection notes")
                    Button(speech.isRecording ? "Stop recording" : "Record voice note",
                           systemImage: speech.isRecording ? "stop.circle" : "mic") {
                        if speech.isRecording { speech.stopRecording() }
                        else { Task { await speech.requestAuthorization(); speech.startRecording() } }
                    }.frame(minHeight: 44)
                    if !speech.transcript.isEmpty {
                        Text(speech.transcript)
                        Button("Append transcript to notes") {
                            notes += (notes.isEmpty ? "" : "\n") + speech.transcript
                            speech.transcript = ""
                        }.frame(minHeight: 44)
                    }
                    if let message = speech.errorMessage { Text(message).foregroundStyle(.red) }
                    Text("You can type notes if speech is unavailable.").font(.caption)
                    Divider()
                    Text("Photo evidence (optional)").font(.headline)
                    if let capturedImage {
                        Image(uiImage: capturedImage).resizable().scaledToFit().frame(maxHeight: 240)
                            .accessibilityLabel("Captured inspection photo")
                    }
                    PhotosPicker("Choose photo", selection: $photoItem, matching: .images)
                        .disabled(isAnalyzing).frame(minHeight: 44)
                    if CameraPicker.isCameraAvailable {
                        Button("Take photo", systemImage: "camera") { showCamera = true }
                            .disabled(isAnalyzing).frame(minHeight: 44)
                    }
                    if isAnalyzing { ProgressView("Saving and analysing photo…") }
                    if let result = hazardResult {
                        Text(result.label).font(.headline)
                        if result.isHazard {
                            Text("Image label confidence: \(Int(result.confidence * 100))%. Review this suggestion; it is not a safety assessment.")
                        }
                    }
                    Button("Complete Inspection & Review") {
                        pendingDraft = InspectionDraft(id: draftID, task: selectedTask,
                            hazardTag: hazardResult?.isHazard == true ? hazardResult?.label : nil,
                            hazardConfidence: hazardResult?.isHazard == true ? hazardResult?.confidence : nil,
                            voiceNote: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
                            photoName: photoName, checkpoints: checkpoints, startedAt: startedAt)
                    }
                    .buttonStyle(.borderedProminent).frame(minHeight: 44)
                    .disabled(isAnalyzing || speech.isRecording || !allChecked)
                    if !allChecked { Text("Choose an outcome for every checkpoint to continue.").font(.caption) }
                } else {
                    ContentUnavailableView("No pending task selected", systemImage: "checkmark.circle",
                        description: Text("Choose a task from Home or the site task list."))
                }
            }.padding(20)
        }
        .background(AppColors.background)
        .onChange(of: selectedTask?.id, initial: true) { _, _ in resetDraft() }
        .onDisappear { speech.stopRecording() }
        .onChange(of: photoItem) { _, item in
            Task {
                do {
                    guard let data = try await item?.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else { return }
                    await capture(image)
                } catch { errorMessage = "Could not read photo: \(error.localizedDescription)" }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in Task { await capture(image) } }.ignoresSafeArea()
        }
        .sheet(item: $pendingDraft) { draft in NavigationStack { ReviewSignOffView(draft: draft) } }
        .alert("Photo unavailable", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private var allChecked: Bool {
        !checkpoints.isEmpty && checkpoints.allSatisfy {
            switch $0.status { case .passed, .flagged, .remediated: return true; default: return false }
        }
    }

    private func resetDraft() {
        draftID = UUID(); startedAt = Date(); notes = ""; photoName = nil
        capturedImage = nil; hazardResult = nil
        checkpoints = ["Asset condition", "Leaks and visible damage", "Work area safety"].enumerated().map {
            Checkpoint(index: $0.offset + 1, title: $0.element, status: .pending)
        }
    }

    private func capture(_ image: UIImage) async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        do {
            guard let data = image.jpegData(compressionQuality: 0.85) else { throw CocoaError(.fileWriteUnknown) }
            let name = try PhotoStore().save(data)
            capturedImage = image; photoName = name
            hazardResult = await HazardClassifier.shared.classify(image: image)
        } catch { errorMessage = "Could not save photo: \(error.localizedDescription)" }
    }
}

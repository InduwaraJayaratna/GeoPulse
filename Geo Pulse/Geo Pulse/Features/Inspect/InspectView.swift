import SwiftUI
import PhotosUI

struct InspectView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var speech = SpeechService()

    @State private var selectedTask: FieldTask
    @State private var photoItem: PhotosPickerItem?
    @State private var capturedImage: UIImage?
    @State private var isAnalyzing: Bool = false
    @State private var hazardResult: HazardClassificationResult?
    @State private var transcript: String = "\"Pressure reading is 142 PSI. Slight oxidation on flange bolts.\""
    @State private var recordingSeconds: Int = 8
    @State private var showReview: Bool = false

    init() {
        _selectedTask = State(initialValue: SampleData.tasks[0])
    }

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(title: "Inspect")
            ScrollView {
                VStack(spacing: 16) {
                    protocolCard
                    voiceCard
                    visualCaptureCard
                    PrimaryButton(title: "Complete Inspection & Review", icon: "checkmark.circle") {
                        showReview = true
                    }
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .sheet(isPresented: $showReview) {
            NavigationStack {
                ReviewSignOffView(task: selectedTask)
            }
        }
        .task { await speech.requestAuthorization() }
    }

    private var protocolCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 6) {
                        Circle().fill(AppColors.accentSuccess).frame(width: 6, height: 6)
                        Text("Protocol \(selectedTask.protocolCode)")
                            .font(AppTypography.captionBold())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppColors.accentSuccessSoft)
                    .clipShape(Capsule())
                    .foregroundStyle(AppColors.accentSuccess)
                    Spacer()
                    Text("Task #\(selectedTask.ticketNumber)")
                        .font(AppTypography.captionBold())
                        .foregroundStyle(AppColors.textSecondary)
                }
                Text(selectedTask.title)
                    .font(AppTypography.title())
                    .foregroundStyle(AppColors.textPrimary)
                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                    Text("Riverside Plant · \(selectedTask.siteName)")
                        .font(AppTypography.caption())
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }

    private var voiceCard: some View {
        CardContainer {
            VStack(spacing: 16) {
                HStack {
                    Text("Voice Observation")
                        .font(AppTypography.titleSmall())
                    Spacer()
                    Text("Tap & Hold to Talk")
                        .font(AppTypography.caption())
                        .foregroundStyle(AppColors.textTertiary)
                }

                VStack(spacing: 12) {
                    Button {} label: {
                        ZStack {
                            Circle().fill(AppColors.primary).frame(width: 72, height: 72)
                            Image(systemName: speech.isRecording ? "waveform" : "mic.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.1)
                            .onEnded { _ in speech.startRecording() }
                    )
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { _ in speech.stopRecording() }
                    )

                    waveformView

                    Text("Hold to record inspection notes")
                        .font(AppTypography.caption())
                        .foregroundStyle(AppColors.textSecondary)
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "waveform")
                        .foregroundStyle(AppColors.primary)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Transcription")
                                .font(AppTypography.captionBold())
                            Spacer()
                            Text(String(format: "00:%02d", recordingSeconds))
                                .font(AppTypography.caption())
                                .foregroundStyle(AppColors.textTertiary)
                        }
                        Text(speech.transcript.isEmpty ? transcript : "\"\(speech.transcript)\"")
                            .font(AppTypography.body())
                            .foregroundStyle(AppColors.textPrimary)
                    }
                }
                .padding(12)
                .background(AppColors.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var waveformView: some View {
        HStack(spacing: 3) {
            ForEach(0..<24, id: \.self) { i in
                Capsule()
                    .fill(AppColors.primary.opacity(waveformIntensity(for: i)))
                    .frame(width: 4, height: waveformHeight(for: i))
            }
        }
        .frame(height: 36)
    }

    private func waveformIntensity(for index: Int) -> Double {
        let base = sin(Double(index) * 0.6) * 0.5 + 0.5
        return 0.3 + base * 0.7
    }

    private func waveformHeight(for index: Int) -> CGFloat {
        let base = abs(sin(Double(index) * 0.9))
        return 10 + CGFloat(base) * 22
    }

    private var visualCaptureCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Visual Capture")
                        .font(AppTypography.titleSmall())
                    Spacer()
                    Text("Verified Asset")
                        .font(AppTypography.caption())
                        .foregroundStyle(AppColors.textTertiary)
                }

                ZStack(alignment: .topTrailing) {
                    photoPreview
                    HStack(spacing: 4) {
                        Circle().fill(AppColors.accentSuccess).frame(width: 6, height: 6)
                        Text("Auto-Stabilized")
                            .font(AppTypography.label())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white)
                    .clipShape(Capsule())
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(10)
                }

                if isAnalyzing {
                    HStack(spacing: 8) {
                        ProgressView().tint(AppColors.primary)
                        Text("Analyzing…")
                            .font(AppTypography.captionBold())
                            .foregroundStyle(AppColors.primary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(AppColors.primarySoft)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else if let result = hazardResult {
                    HStack(spacing: 10) {
                        Image(systemName: result.label == "No hazard detected" ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(result.label == "No hazard detected" ? AppColors.accentSuccess : AppColors.accentWarning)
                        Text("\(result.label) · \(Int(result.confidence * 100))% confidence")
                            .font(AppTypography.captionBold())
                            .foregroundStyle(result.label == "No hazard detected" ? AppColors.accentSuccess : AppColors.accentWarning)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(result.label == "No hazard detected" ? AppColors.accentSuccessSoft : AppColors.accentWarningSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppColors.accentWarning)
                        Text("Surface corrosion detected · 94% confidence")
                            .font(AppTypography.captionBold())
                            .foregroundStyle(AppColors.accentWarning)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.accentWarningSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                PhotosPicker(selection: $photoItem, matching: .images) {
                    HStack(spacing: 8) {
                        Image(systemName: "camera")
                        Text("Retake Photo")
                            .font(AppTypography.bodyBold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(AppColors.textPrimary)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppColors.divider, lineWidth: 1))
                }
                .onChange(of: photoItem) { _, newItem in
                    Task { await loadImage(newItem) }
                }
            }
        }
    }

    private var photoPreview: some View {
        Group {
            if let capturedImage {
                Image(uiImage: capturedImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [AppColors.surfaceAlt, Color(red: 0.78, green: 0.75, blue: 0.70)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    VStack(spacing: 8) {
                        Image(systemName: "camera.aperture")
                            .font(.system(size: 36))
                            .foregroundStyle(AppColors.textTertiary)
                        Text("No photo captured")
                            .font(AppTypography.caption())
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
            }
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func loadImage(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            capturedImage = image
            isAnalyzing = true
            hazardResult = nil
            let result = await HazardClassifier.shared.classify(image: image)
            isAnalyzing = false
            hazardResult = result
        }
    }
}

#Preview {
    InspectView().environmentObject(AppState())
}

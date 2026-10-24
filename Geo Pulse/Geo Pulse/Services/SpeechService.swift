import Foundation
import Speech
import AVFoundation
import Combine

@MainActor
final class SpeechService: ObservableObject {
    @Published var transcript = ""
    @Published private(set) var isRecording = false
    @Published private(set) var isAuthorized = false
    @Published private(set) var errorMessage: String?
    private let recognizer = SFSpeechRecognizer()
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var hasTap = false
    private var generation = UUID()

    func requestAuthorization() async {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        let microphone = await AVAudioApplication.requestRecordPermission()
        isAuthorized = status == .authorized && microphone
        errorMessage = isAuthorized ? nil : "Speech or microphone permission is disabled. Type your notes or enable access in Settings."
    }

    func startRecording() {
        guard isAuthorized, !isRecording else { return }
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition is unavailable. You can type your notes."
            return
        }
        errorMessage = nil
        let currentGeneration = UUID()
        generation = currentGeneration
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true)
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            self.request = request
            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw CocoaError(.featureUnsupported) }
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
            hasTap = true
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
            transcript = ""
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let text = result?.bestTranscription.formattedString
                let finished = result?.isFinal == true
                let message = error?.localizedDescription
                Task { @MainActor [weak self] in
                    guard let self, self.generation == currentGeneration else { return }
                    if let text { self.transcript = text }
                    if let message { self.errorMessage = "Recording stopped: \(message). You can type your notes." }
                    if finished || message != nil { self.stopRecording() }
                }
            }
        } catch {
            stopRecording()
            errorMessage = "Could not start recording: \(error.localizedDescription). You can type your notes."
        }
    }

    func stopRecording() {
        generation = UUID()
        guard hasTap || isRecording || request != nil else { return }
        audioEngine.stop()
        if hasTap { audioEngine.inputNode.removeTap(onBus: 0); hasTap = false }
        request?.endAudio()
        task?.cancel()
        task = nil; request = nil; isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

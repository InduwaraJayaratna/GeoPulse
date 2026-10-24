import Foundation
import UIKit
import Vision
import CoreImage
import CoreML

struct HazardClassificationResult {
    let label: String
    let confidence: Double
    let rawTopIdentifier: String?
    var isHazard: Bool { label != HazardMapper.fallbackLabel && label != HazardMapper.unavailableLabel }
}

/// On-device image classifier for construction/industrial hazards.
///
/// Primary path: a Create ML–trained image classifier shipped in the bundle as
/// `HazardClassifier.mlmodel` (Xcode compiles it to `HazardClassifier.mlmodelc`
/// at build time). The model's own class labels drive the UI directly — no
/// keyword guessing.
///
/// Fallback path: Apple's built-in `VNClassifyImageRequest` plus the keyword
/// mapper. This runs only when the custom model is missing from the bundle, so
/// the app remains functional until the trained model is dropped in.
final class HazardClassifier {
    static let shared = HazardClassifier()

    /// Resource name (without extension) of the Create ML export dropped into
    /// the project. Must match the `.mlmodel` filename.
    private static let modelResourceName = "HazardClassifier"

    private let coreMLModel: VNCoreMLModel?

    init() {
        self.coreMLModel = Self.loadBundledModel(named: Self.modelResourceName)
    }

    func classify(image: UIImage) async -> HazardClassificationResult {
        guard let cgImage = image.cgImage ?? CIContext().createCGImage(
            CIImage(image: image) ?? CIImage(),
            from: CGRect(origin: .zero, size: image.size)
        ) else {
            return HazardClassificationResult(
                label: HazardMapper.unavailableLabel,
                confidence: 0,
                rawTopIdentifier: nil
            )
        }

        if let model = coreMLModel {
            let observations = await performCoreMLClassification(on: cgImage, model: model)
            return mapCoreMLResult(observations)
        }

        let observations = await performVisionClassification(on: cgImage)
        let mapperObservations = observations.map {
            HazardMapper.Observation(identifier: $0.identifier, confidence: Double($0.confidence))
        }
        return HazardMapper.classify(observations: mapperObservations)
    }

    private nonisolated func performCoreMLClassification(
        on cgImage: CGImage,
        model: VNCoreMLModel
    ) async -> [VNClassificationObservation] {
        await Task.detached(priority: .userInitiated) {
            let request = VNCoreMLRequest(model: model)
            request.imageCropAndScaleOption = .centerCrop
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
                return (request.results as? [VNClassificationObservation]) ?? []
            } catch {
                return []
            }
        }.value
    }

    private nonisolated func performVisionClassification(on cgImage: CGImage) async -> [VNClassificationObservation] {
        await Task.detached(priority: .userInitiated) {
            let request = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
                return request.results ?? []
            } catch {
                return []
            }
        }.value
    }

    private func mapCoreMLResult(_ observations: [VNClassificationObservation]) -> HazardClassificationResult {
        guard let top = observations.first else {
            return HazardClassificationResult(label: HazardMapper.unavailableLabel, confidence: 0, rawTopIdentifier: nil)
        }
        let rawId = top.identifier
        let label = Self.prettify(rawId)
        let clamped = max(0.0, min(1.0, Double(top.confidence)))
        return HazardClassificationResult(label: label, confidence: clamped, rawTopIdentifier: rawId)
    }

    /// Normalises raw model labels (`exposed_wiring`, `no_hazard`) into the
    /// capitalised strings the UI already renders. "No hazard" variants map to
    /// the shared fallback so `HazardClassificationResult.isHazard` keeps its
    /// existing semantics.
    static func prettify(_ identifier: String) -> String {
        let normalized = identifier
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if normalized.isEmpty || normalized == "no hazard" || normalized == "none" || normalized == "safe" {
            return HazardMapper.fallbackLabel
        }
        return normalized.prefix(1).uppercased() + normalized.dropFirst()
    }

    private static func loadBundledModel(named name: String) -> VNCoreMLModel? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc"),
              let mlModel = try? MLModel(contentsOf: url),
              let visionModel = try? VNCoreMLModel(for: mlModel) else {
            return nil
        }
        return visionModel
    }
}

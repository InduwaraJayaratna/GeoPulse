import Foundation
import UIKit
import Vision
import CoreImage

struct HazardClassificationResult {
    let label: String
    let confidence: Double
    let rawTopIdentifier: String?
}

/// On-device image classifier powered by Vision's built-in `VNClassifyImageRequest`.
///
/// Runs Apple's pre-trained ImageNet-style classifier locally, then maps the top
/// identifiers to GeoPulse hazard categories via keyword heuristics. No network
/// call is ever made and no model file is bundled — the classifier is part of
/// the Vision framework itself.
final class HazardClassifier {
    static let shared = HazardClassifier()

    private let hazardKeywords: [(hazard: String, keywords: [String])] = [
        ("Surface corrosion", ["rust", "corrosion", "patina", "oxidation", "weathered", "tarnish"]),
        ("Exposed wiring", ["wire", "cable", "cord", "electrical", "circuit", "electronics", "plug"]),
        ("Structural crack", ["crack", "fracture", "fissure", "split", "broken", "damage"]),
        ("Fluid leak", ["oil", "water", "stain", "puddle", "leak", "wet", "spill", "liquid"]),
        ("Structural wear", ["metal", "steel", "iron", "pipe", "pipework", "machinery", "mechanical", "valve", "flange"]),
        ("Debris / clutter", ["debris", "waste", "trash", "clutter", "pile", "junk", "garbage"]),
        ("Smoke / fire risk", ["smoke", "fire", "flame", "burn", "soot", "ember"])
    ]

    func classify(image: UIImage) async -> HazardClassificationResult {
        guard let cgImage = image.cgImage ?? CIContext().createCGImage(
            CIImage(image: image) ?? CIImage(),
            from: CGRect(origin: .zero, size: image.size)
        ) else {
            return HazardClassificationResult(
                label: "No hazard detected",
                confidence: 0.6,
                rawTopIdentifier: nil
            )
        }

        let observations = await performClassification(on: cgImage)

        for observation in observations.prefix(50) {
            let identifier = observation.identifier.lowercased()
            for mapping in hazardKeywords {
                if mapping.keywords.contains(where: { identifier.contains($0) }) {
                    let confidence = max(0.65, min(0.98, Double(observation.confidence)))
                    return HazardClassificationResult(
                        label: mapping.hazard,
                        confidence: confidence,
                        rawTopIdentifier: observation.identifier
                    )
                }
            }
        }

        return HazardClassificationResult(
            label: "No hazard detected",
            confidence: 0.78,
            rawTopIdentifier: observations.first?.identifier
        )
    }

    private nonisolated func performClassification(on cgImage: CGImage) async -> [VNClassificationObservation] {
        await Task.detached(priority: .userInitiated) {
            let request = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
                return (request.results as? [VNClassificationObservation]) ?? []
            } catch {
                return []
            }
        }.value
    }
}

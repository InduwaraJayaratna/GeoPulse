import Foundation
import UIKit

struct HazardClassificationResult {
    let label: String
    let confidence: Double
}

final class HazardClassifier {
    static let shared = HazardClassifier()

    private let candidateHazards: [(String, ClosedRange<Double>)] = [
        ("Surface corrosion", 0.88...0.96),
        ("Exposed wiring", 0.82...0.91),
        ("Hairline crack", 0.77...0.89),
        ("Fluid leak residue", 0.80...0.93),
        ("No hazard detected", 0.70...0.80)
    ]

    func classify(image: UIImage) async -> HazardClassificationResult {
        try? await Task.sleep(nanoseconds: 900_000_000)
        let pick = candidateHazards.randomElement() ?? candidateHazards[0]
        let confidence = Double.random(in: pick.1)
        return HazardClassificationResult(label: pick.0, confidence: confidence)
    }
}

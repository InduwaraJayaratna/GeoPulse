import Foundation

/// Pure keyword→hazard mapping extracted from `HazardClassifier` so the mapping
/// rules can be unit-tested without invoking Vision. Shared by production code
/// and tests to avoid drift.
///
/// Keyword suggestions preserve the classifier's confidence. Empty observations
/// mean analysis was unavailable, never a claim that the scene is safe.
struct HazardMapper {

    struct Observation {
        let identifier: String
        let confidence: Double
    }

    static let hazardKeywords: [(hazard: String, keywords: [String])] = [
        ("Surface corrosion", ["rust", "corrosion", "patina", "oxidation", "oxidized", "weathered", "tarnish"]),
        ("Exposed wiring", ["wire", "cable", "cord", "electrical", "circuit", "electronics", "plug"]),
        ("Structural crack", ["crack", "fracture", "fissure", "split", "broken", "damage"]),
        ("Fluid leak", ["oil", "water", "stain", "puddle", "leak", "wet", "spill", "liquid"]),
        ("Structural wear", ["metal", "steel", "iron", "pipe", "pipework", "machinery", "mechanical", "valve", "flange"]),
        ("Debris / clutter", ["debris", "waste", "trash", "clutter", "pile", "junk", "garbage"]),
        ("Smoke / fire risk", ["smoke", "fire", "flame", "burn", "soot", "ember"])
    ]

    static let fallbackLabel = "No hazard suggestion"
    static let unavailableLabel = "Analysis unavailable — inspect the photo manually"
    static let fallbackConfidence = 0.0
    static let confidenceFloor = 0.0
    static let confidenceCeiling = 1.0

    /// Walks the observations in order (top-first) and returns the first keyword
    /// match. If no observation triggers a mapping, returns the fallback label.
    static func classify(observations: [Observation]) -> HazardClassificationResult {
        guard !observations.isEmpty else {
            return HazardClassificationResult(label: unavailableLabel, confidence: 0, rawTopIdentifier: nil)
        }
        for observation in observations.prefix(50) where observation.confidence.isFinite {
            let identifier = observation.identifier.lowercased()
            for mapping in hazardKeywords {
                if mapping.keywords.contains(where: { identifier.contains($0) }) {
                    let clamped = max(confidenceFloor, min(confidenceCeiling, observation.confidence))
                    return HazardClassificationResult(
                        label: mapping.hazard,
                        confidence: clamped,
                        rawTopIdentifier: observation.identifier
                    )
                }
            }
        }
        return HazardClassificationResult(
            label: fallbackLabel,
            confidence: fallbackConfidence,
            rawTopIdentifier: observations.first?.identifier
        )
    }
}

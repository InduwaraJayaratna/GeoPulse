import Foundation

/// Pure keyword→hazard mapping extracted from `HazardClassifier` so the mapping
/// rules can be unit-tested without invoking Vision. Shared by production code
/// and tests to avoid drift.
///
/// Each raw identifier (e.g. "oxidized_iron_pipe") is checked against the
/// keyword list for each hazard, in order. First match wins. Confidence is
/// clamped to [0.65, 0.98] to avoid showing suspiciously-high or
/// implausibly-low values to the user.
struct HazardMapper {

    struct Observation {
        let identifier: String
        let confidence: Double
    }

    static let hazardKeywords: [(hazard: String, keywords: [String])] = [
        ("Surface corrosion", ["rust", "corrosion", "patina", "oxidation", "weathered", "tarnish"]),
        ("Exposed wiring", ["wire", "cable", "cord", "electrical", "circuit", "electronics", "plug"]),
        ("Structural crack", ["crack", "fracture", "fissure", "split", "broken", "damage"]),
        ("Fluid leak", ["oil", "water", "stain", "puddle", "leak", "wet", "spill", "liquid"]),
        ("Structural wear", ["metal", "steel", "iron", "pipe", "pipework", "machinery", "mechanical", "valve", "flange"]),
        ("Debris / clutter", ["debris", "waste", "trash", "clutter", "pile", "junk", "garbage"]),
        ("Smoke / fire risk", ["smoke", "fire", "flame", "burn", "soot", "ember"])
    ]

    static let fallbackLabel = "No hazard detected"
    static let fallbackConfidence = 0.78
    static let confidenceFloor = 0.65
    static let confidenceCeiling = 0.98

    /// Walks the observations in order (top-first) and returns the first keyword
    /// match. If no observation triggers a mapping, returns the fallback label.
    static func classify(observations: [Observation]) -> HazardClassificationResult {
        for observation in observations.prefix(50) {
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

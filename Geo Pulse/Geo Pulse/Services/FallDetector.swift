import Foundation

/// Pure, side-effect-free detector for the "impact followed by stillness"
/// pattern consistent with a fall. Extracted from `MotionService` so the
/// decision logic can be unit-tested with synthetic samples.
///
/// Thresholds:
/// - Impact: user-acceleration magnitude above 3.0 g
/// - Stillness window: 1.0 … 3.0 seconds after the impact
/// - Stillness: combined gyroscope rotation magnitude below 0.2 rad/s
///
/// Feed samples via `ingest(sample:)` in time order. Returns `true` on the
/// sample that closes a fall pattern, resetting internal state.
final class FallDetector {

    struct Sample: Equatable {
        let accelerationMagnitude: Double
        let rotationMagnitude: Double
        let timestamp: Date
    }

    struct Thresholds: Equatable {
        var impactG: Double = 3.0
        var stillnessWindowStart: TimeInterval = 1.0
        var stillnessWindowEnd: TimeInterval = 3.0
        var stillnessRotation: Double = 0.2
    }

    let thresholds: Thresholds
    private(set) var lastImpactAt: Date?

    init(thresholds: Thresholds = Thresholds()) {
        self.thresholds = thresholds
    }

    @discardableResult
    func ingest(sample: Sample) -> Bool {
        if sample.accelerationMagnitude > thresholds.impactG {
            lastImpactAt = sample.timestamp
            return false
        }
        guard let impactTime = lastImpactAt else { return false }

        let elapsed = sample.timestamp.timeIntervalSince(impactTime)
        if elapsed > thresholds.stillnessWindowEnd {
            lastImpactAt = nil
            return false
        }
        if elapsed >= thresholds.stillnessWindowStart,
           sample.rotationMagnitude < thresholds.stillnessRotation {
            lastImpactAt = nil
            return true
        }
        return false
    }

    func reset() {
        lastImpactAt = nil
    }
}

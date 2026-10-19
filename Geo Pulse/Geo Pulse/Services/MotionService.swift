import Foundation
import CoreMotion
import Combine

/// Monitors accelerometer + gyroscope for an impact-then-stillness pattern consistent with a fall.
///
/// Algorithm: a user-acceleration magnitude spike above ~3g marks a candidate impact.
/// If, 1–3 seconds later, rotation rate drops below a stillness threshold, we treat
/// it as a probable fall and emit `.possibleFallDetected`. The caller (AppState) is
/// responsible for presenting the countdown alert and escalation.
@MainActor
final class MotionService: ObservableObject {
    @Published private(set) var isMonitoring: Bool = false
    @Published private(set) var possibleFallDetected: Bool = false
    @Published private(set) var latestMagnitude: Double = 0

    nonisolated(unsafe) private let motionManager = CMMotionManager()
    nonisolated(unsafe) private let queue: OperationQueue = {
        let q = OperationQueue()
        q.name = "GeoPulse.MotionService"
        q.qualityOfService = .userInitiated
        return q
    }()

    nonisolated(unsafe) private var highImpactAt: Date?

    func startMonitoring() {
        guard motionManager.isDeviceMotionAvailable else { return }
        guard !isMonitoring else { return }
        isMonitoring = true
        motionManager.deviceMotionUpdateInterval = 1.0 / 25.0
        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.evaluate(motion: motion)
        }
    }

    func stopMonitoring() {
        motionManager.stopDeviceMotionUpdates()
        isMonitoring = false
        possibleFallDetected = false
        highImpactAt = nil
    }

    func acknowledgeFall() {
        possibleFallDetected = false
    }

    /// Deterministic trigger for demo / viva purposes. Emits the same signal a real fall would.
    func simulateFall() {
        possibleFallDetected = true
        NotificationCenter.default.post(name: .possibleFallDetected, object: nil)
    }

    nonisolated private func evaluate(motion: CMDeviceMotion) {
        let magnitude = sqrt(
            pow(motion.userAcceleration.x, 2) +
            pow(motion.userAcceleration.y, 2) +
            pow(motion.userAcceleration.z, 2)
        )

        if magnitude > 3.0 {
            highImpactAt = Date()
        }

        if let impactTime = highImpactAt {
            let interval = Date().timeIntervalSince(impactTime)
            let rotationMagnitude = abs(motion.rotationRate.x) + abs(motion.rotationRate.y) + abs(motion.rotationRate.z)
            if interval > 1.0, interval < 3.0, rotationMagnitude < 0.2 {
                highImpactAt = nil
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.latestMagnitude = magnitude
                    self.possibleFallDetected = true
                    NotificationCenter.default.post(name: .possibleFallDetected, object: nil)
                }
            }
        }
    }
}

extension Notification.Name {
    static let possibleFallDetected = Notification.Name("GeoPulse.possibleFallDetected")
}

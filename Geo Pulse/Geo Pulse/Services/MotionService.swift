import Foundation
import CoreMotion
import Combine

@MainActor
final class MotionService: ObservableObject {
    @Published var isMonitoring: Bool = false
    @Published var possibleFallDetected: Bool = false

    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    private var highImpactAt: Date?

    func startMonitoring() {
        guard motionManager.isDeviceMotionAvailable else { return }
        isMonitoring = true
        motionManager.deviceMotionUpdateInterval = 1.0 / 25.0
        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let self = self, let motion = motion else { return }
            self.evaluate(motion: motion)
        }
    }

    func stopMonitoring() {
        motionManager.stopDeviceMotionUpdates()
        isMonitoring = false
        possibleFallDetected = false
        highImpactAt = nil
    }

    private func evaluate(motion: CMDeviceMotion) {
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
                Task { @MainActor in
                    self.possibleFallDetected = true
                    NotificationCenter.default.post(name: .possibleFallDetected, object: nil)
                }
                highImpactAt = nil
            }
        }
    }
}

extension Notification.Name {
    static let possibleFallDetected = Notification.Name("GeoPulse.possibleFallDetected")
}

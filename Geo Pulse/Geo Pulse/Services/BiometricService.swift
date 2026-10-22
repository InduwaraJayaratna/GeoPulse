import Foundation
import LocalAuthentication
import Combine

@MainActor
final class BiometricService: ObservableObject {

    enum Availability {
        case faceID
        case touchID
        case opticID
        case passcodeOnly
        case unavailable(String)

        var displayName: String {
            switch self {
            case .faceID: return "Face ID"
            case .touchID: return "Touch ID"
            case .opticID: return "Optic ID"
            case .passcodeOnly: return "Device Passcode"
            case .unavailable: return "Unavailable"
            }
        }

        var icon: String {
            switch self {
            case .faceID: return "faceid"
            case .touchID: return "touchid"
            case .opticID: return "opticid"
            case .passcodeOnly: return "lock.rectangle"
            case .unavailable: return "exclamationmark.lock"
            }
        }
    }

    enum AuthResult {
        case success
        case cancelled
        case failed(String)
    }

    @Published private(set) var availability: Availability = .unavailable("Not checked")

    init() {
        availability = Self.detect()
    }

    func refreshAvailability() {
        availability = Self.detect()
    }

    func authenticate(reason: String = "Sign in to your GeoPulse shift") async -> AuthResult {
        let context = LAContext()
        var error: NSError?
        let policy: LAPolicy = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            ? .deviceOwnerAuthenticationWithBiometrics
            : .deviceOwnerAuthentication

        guard context.canEvaluatePolicy(policy, error: &error) else {
            return .failed(error?.localizedDescription ?? "Biometric authentication is not available on this device.")
        }

        do {
            let ok = try await context.evaluatePolicy(policy, localizedReason: reason)
            return ok ? .success : .cancelled
        } catch let authError as LAError {
            switch authError.code {
            case .userCancel, .systemCancel, .appCancel: return .cancelled
            case .userFallback: return .cancelled
            default: return .failed(authError.localizedDescription)
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private static func detect() -> Availability {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID: return .faceID
            case .touchID: return .touchID
            case .opticID: return .opticID
            default: return .passcodeOnly
            }
        }
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            return .passcodeOnly
        }
        return .unavailable(error?.localizedDescription ?? "Not enrolled")
    }
}

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var biometrics = BiometricService()

    @State private var email: String = "alex.mercer@energy.org"
    @State private var password: String = "••••••"
    @State private var rememberHardware: Bool = true
    @State private var showPassword: Bool = false
    @State private var isAuthenticating: Bool = false
    @State private var authError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                connectionPill
                credentialsCard
                dividerRow
                biometricRow
                offlineCard
                supportLink
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
            .padding(.bottom, 32)
        }
        .background(AppColors.background.ignoresSafeArea())
    }

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppColors.primary)
                    .frame(width: 64, height: 64)
                Image(systemName: "scope")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                Circle()
                    .fill(AppColors.accentSuccess)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(AppColors.background, lineWidth: 3))
                    .offset(x: 24, y: 24)
            }
            LabelCaps(text: "GeoPulse Field Operations")
            Text("Sign In to Station")
                .font(AppTypography.largeTitle())
                .foregroundStyle(AppColors.textPrimary)
            Text("Authenticate to access assigned geofences, active hazard telemetry, and offline sync.")
                .font(AppTypography.body())
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    private var connectionPill: some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(AppColors.primary)
            Text("Connected to Riverside Mesh Bridge")
                .font(AppTypography.captionBold())
                .foregroundStyle(AppColors.textPrimary)
            Text("•")
                .foregroundStyle(AppColors.textTertiary)
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                Text("ENCRYPTED").tracking(0.6)
            }
            .font(AppTypography.label())
            .foregroundStyle(AppColors.accentWarning)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppColors.surfaceAlt)
        .clipShape(Capsule())
    }

    private var credentialsCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 16) {
                fieldLabel("Inspector ID / Enterprise Email", suffix: "SEC-LEVEL 3")
                HStack {
                    Image(systemName: "person.text.rectangle")
                        .foregroundStyle(AppColors.textTertiary)
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                    Button {
                        email = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
                .padding(14)
                .background(AppColors.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                fieldLabel("Field Access PIN / Password", suffix: "NUMERIC OR ALPHANUM")
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(AppColors.textTertiary)
                    if showPassword {
                        TextField("Password", text: $password)
                    } else {
                        SecureField("Password", text: $password)
                    }
                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
                .padding(14)
                .background(AppColors.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Remember Station Hardware")
                            .font(AppTypography.bodyBold())
                        Text("Binds cryptographic telemetry keys to this mobile unit")
                            .font(AppTypography.caption())
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    Spacer()
                    Toggle("", isOn: $rememberHardware)
                        .labelsHidden()
                        .tint(AppColors.primary)
                }

                PrimaryButton(title: "Sign In to Active Shift", icon: "arrow.right") {
                    appState.signIn()
                }
            }
        }
    }

    private func fieldLabel(_ title: String, suffix: String) -> some View {
        HStack {
            Text(title)
                .font(AppTypography.bodyBold())
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
            Text(suffix.uppercased())
                .font(AppTypography.label())
                .tracking(0.6)
                .foregroundStyle(AppColors.textTertiary)
        }
    }

    private var dividerRow: some View {
        HStack(spacing: 12) {
            Rectangle().fill(AppColors.divider).frame(height: 1)
            Text("OR AUTHENTICATE VIA")
                .font(AppTypography.label())
                .tracking(0.6)
                .foregroundStyle(AppColors.textTertiary)
            Rectangle().fill(AppColors.divider).frame(height: 1)
        }
    }

    private var biometricRow: some View {
        HStack(spacing: 14) {
            Button {
                triggerBiometricAuth()
            } label: {
                biometricCard(
                    icon: biometrics.availability.icon,
                    title: biometricCardTitle,
                    subtitle: biometricCardSubtitle,
                    caption: biometricCardCaption,
                    captionColor: biometricCardCaptionColor
                )
            }
            .buttonStyle(.plain)
            .disabled(isAuthenticating || isUnavailable)

            biometricCard(
                icon: "dot.radiowaves.left.and.right",
                title: "Physical Badge",
                subtitle: "NFC / RFID tap",
                caption: "Tap top of device",
                captionColor: AppColors.accentWarning
            )
        }
    }

    private var isUnavailable: Bool {
        if case .unavailable = biometrics.availability { return true }
        return false
    }

    private var biometricCardTitle: String {
        switch biometrics.availability {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        case .passcodeOnly: return "Device Passcode"
        case .unavailable: return "Biometrics Off"
        }
    }

    private var biometricCardSubtitle: String {
        switch biometrics.availability {
        case .unavailable: return "Not enrolled on this device"
        case .passcodeOnly: return "Use device passcode"
        default: return "Biometric quick unlock"
        }
    }

    private var biometricCardCaption: String {
        if let authError { return authError }
        if isAuthenticating { return "Scanning…" }
        switch biometrics.availability {
        case .unavailable: return "Unavailable"
        default: return "Tap to sign in"
        }
    }

    private var biometricCardCaptionColor: Color {
        if authError != nil { return .red }
        return isUnavailable ? AppColors.textTertiary : AppColors.primary
    }

    private func triggerBiometricAuth() {
        guard !isAuthenticating, !isUnavailable else { return }
        isAuthenticating = true
        authError = nil
        Task {
            let reason = "Sign in to GeoPulse to access your assigned geofences and inspections."
            let result = await biometrics.authenticate(reason: reason)
            isAuthenticating = false
            switch result {
            case .success:
                appState.signIn()
            case .cancelled:
                break
            case .failed(let message):
                authError = message
            }
        }
    }

    private func biometricCard(icon: String, title: String, subtitle: String, caption: String, captionColor: Color) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.primarySoft)
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColors.primary)
                }
                Text(title)
                    .font(AppTypography.bodyBold())
                Text(subtitle)
                    .font(AppTypography.caption())
                    .foregroundStyle(AppColors.textSecondary)
                HStack(spacing: 4) {
                    if isAuthenticating {
                        ProgressView().scaleEffect(0.6).tint(captionColor)
                    }
                    Text(caption)
                        .font(AppTypography.captionBold())
                        .foregroundStyle(captionColor)
                        .lineLimit(2)
                    if !isAuthenticating {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(captionColor)
                    }
                }
            }
        }
    }

    private var offlineCard: some View {
        CardContainer {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppColors.accentSuccessSoft)
                        .frame(width: 36, height: 36)
                    Image(systemName: "checkmark.icloud.fill")
                        .foregroundStyle(AppColors.accentSuccess)
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Offline Sign In Enabled")
                            .font(AppTypography.bodyBold())
                        StatusBadge(text: "ACTIVE", tone: .success)
                    }
                    Text("Cached biometric credentials are valid for 8 more hours without cellular or satellite backhaul. Telemetry syncs automatically upon mesh reconnect.")
                        .font(AppTypography.caption())
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }

    private var supportLink: some View {
        HStack(spacing: 8) {
            Image(systemName: "headphones")
                .foregroundStyle(AppColors.primary)
            Text("Having trouble? Contact Dispatch / Site Safety Commander")
                .font(AppTypography.captionBold())
                .foregroundStyle(AppColors.primary)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    LoginView().environmentObject(AppState())
}

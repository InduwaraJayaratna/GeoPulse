import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var biometrics = BiometricService()

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isPasswordVisible = false
    @State private var isAuthenticating = false
    @State private var authError: String?
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    private let registeredEmail = SampleData.currentUser.email
    private let registeredPassword = "GeoPulse2026"

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.primaryDeep, AppColors.primary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    header
                        .padding(.top, 48)
                    loginCard
                    footer
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .alert("Sign in failed", isPresented: Binding(
            get: { authError != nil },
            set: { if !$0 { authError = nil } }
        )) {
            Button("OK") { authError = nil }
        } message: {
            Text(authError ?? "")
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 88, height: 88)
                Image(systemName: "scope")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text("GeoPulse")
                .font(AppTypography.largeTitle())
                .foregroundStyle(.white)
            Text("Secure field inspections")
                .font(AppTypography.caption())
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private var loginCard: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Sign in")
                    .font(AppTypography.title())
                    .foregroundStyle(AppColors.textPrimary)
                Text("Use your inspector credentials to continue.")
                    .font(AppTypography.caption())
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            emailField
            passwordField

            PrimaryButton(title: isAuthenticating ? "Signing in…" : "Sign in") {
                attemptCredentialSignIn()
            }
            .disabled(isAuthenticating)

            if case .unavailable = biometrics.availability {
                EmptyView()
            } else {
                dividerRow
                biometricButton
            }
        }
        .padding(24)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.15), radius: 18, x: 0, y: 8)
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Email")
                .font(AppTypography.captionBold())
                .foregroundStyle(AppColors.textSecondary)
            HStack(spacing: 10) {
                Image(systemName: "envelope")
                    .foregroundStyle(AppColors.textTertiary)
                TextField("you@company.com", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
            }
            .padding(14)
            .background(AppColors.surfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Password")
                .font(AppTypography.captionBold())
                .foregroundStyle(AppColors.textSecondary)
            HStack(spacing: 10) {
                Image(systemName: "lock")
                    .foregroundStyle(AppColors.textTertiary)
                Group {
                    if isPasswordVisible {
                        TextField("Enter password", text: $password)
                    } else {
                        SecureField("Enter password", text: $password)
                    }
                }
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit { attemptCredentialSignIn() }
                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                        .foregroundStyle(AppColors.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
            }
            .padding(14)
            .background(AppColors.surfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var dividerRow: some View {
        HStack(spacing: 10) {
            Rectangle().fill(AppColors.divider).frame(height: 1)
            Text("or")
                .font(AppTypography.caption())
                .foregroundStyle(AppColors.textTertiary)
            Rectangle().fill(AppColors.divider).frame(height: 1)
        }
    }

    private var biometricButton: some View {
        Button {
            attemptBiometricSignIn()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: biometrics.availability.icon)
                    .font(.title3)
                Text("Continue with \(biometrics.availability.displayName)")
                    .font(AppTypography.bodyBold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(AppColors.primary)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppColors.primary, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(isAuthenticating)
    }

    private var footer: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.white.opacity(0.75))
                    .font(.caption)
                Text("Credentials never leave this device")
                    .font(AppTypography.caption())
                    .foregroundStyle(.white.opacity(0.85))
            }
            Text("GeoPulse 2.4")
                .font(AppTypography.micro())
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private func attemptCredentialSignIn() {
        focusedField = nil
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            authError = "Enter your email and password to continue."
            return
        }
        guard trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            authError = "Enter a valid email address."
            return
        }
        guard trimmedEmail == registeredEmail.lowercased(), password == registeredPassword else {
            authError = "Those credentials don't match an active inspector account."
            return
        }
        isAuthenticating = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            isAuthenticating = false
            appState.signIn()
        }
    }

    private func attemptBiometricSignIn() {
        focusedField = nil
        isAuthenticating = true
        Task {
            let result = await biometrics.authenticate()
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
}

#Preview {
    LoginView().environmentObject(AppState())
}

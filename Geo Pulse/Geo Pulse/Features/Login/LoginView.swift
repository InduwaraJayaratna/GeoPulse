import SwiftUI

/// Local device access only. Enterprise account authentication requires a backend.
struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var biometrics = BiometricService()
    @State private var isAuthenticating = false
    @State private var authError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Label("GeoPulse", systemImage: "scope").font(.largeTitle.bold())
                Text("Field inspections on your device").font(.title2)
                Text("Record observations and save reports locally. Remote accounts, team delivery, and emergency dispatch are not connected.")
                Text("Device access").font(.headline)
                Button("Unlock with \(biometrics.availability.displayName)") {
                    isAuthenticating = true
                    Task {
                        let result = await biometrics.authenticate()
                        isAuthenticating = false
                        switch result {
                        case .success: appState.signIn()
                        case .cancelled: break
                        case .failed(let message): authError = message
                        }
                    }
                }.buttonStyle(.borderedProminent).frame(minHeight: 44).disabled(isAuthenticating)
                if isAuthenticating { ProgressView("Authenticating…") }
                if let authError { Text(authError).foregroundStyle(.red) }
                Divider()
                Text("Coursework demonstration").font(.headline)
                Text("Demo mode uses a sample inspector and assigned sites. It does not validate an enterprise account.")
                Button("Enter demo mode") { appState.signIn() }
                    .buttonStyle(.bordered).frame(minHeight: 44)
            }.padding(24)
        }.background(AppColors.background)
    }
}

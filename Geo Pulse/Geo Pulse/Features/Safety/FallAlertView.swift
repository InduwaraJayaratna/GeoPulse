import SwiftUI

struct FallAlertView: View {
    let onCancel: () -> Void
    let onEscalate: () -> Void
    @State private var secondsRemaining = 30
    @State private var handled = false
    @AccessibilityFocusState private var focusTitle: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Possible fall detected").font(.largeTitle.bold())
                    .accessibilityFocused($focusTitle)
                    .accessibilityAddTraits(.isHeader)
                Text("A local incident will be recorded in \(secondsRemaining) seconds.")
                Text("Emergency dispatch is not connected. Contact local emergency services if you need help.")
                Button("I'm OK — cancel alert", systemImage: "checkmark.circle") {
                    finish(escalate: false)
                }.buttonStyle(.borderedProminent).frame(minHeight: 44)
                Button("Record incident now") { finish(escalate: true) }
                    .buttonStyle(.bordered).frame(minHeight: 44)
            }.padding(24).frame(maxWidth: .infinity)
        }
        .background(AppColors.background.ignoresSafeArea())
        .task {
            focusTitle = true
            while secondsRemaining > 0 && !handled {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                guard !handled else { return }
                secondsRemaining -= 1
            }
            if !Task.isCancelled { finish(escalate: true) }
        }
    }

    private func finish(escalate: Bool) {
        guard !handled else { return }
        handled = true
        if escalate { onEscalate() } else { onCancel() }
    }
}

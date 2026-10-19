import SwiftUI
import UIKit

struct FallAlertView: View {
    let onCancel: () -> Void
    let onEscalate: () -> Void

    @State private var secondsRemaining: Int = 30
    @State private var timer: Timer?
    private let feedback = UINotificationFeedbackGenerator()

    var body: some View {
        ZStack {
            Color.red.opacity(0.92).ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(.white.opacity(0.15))
                        .frame(width: 160, height: 160)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 160, height: 160)
                        .animation(.linear(duration: 1.0), value: secondsRemaining)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 10) {
                    Text("Possible fall detected")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Dispatch will be alerted in \(secondsRemaining)s")
                        .font(.system(size: 17))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("Tap I'm OK if you can respond.")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.75))
                }

                Spacer()

                Button {
                    stopTimer()
                    onCancel()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("I'm OK — cancel alert")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .foregroundStyle(.red)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 24)

                Button {
                    stopTimer()
                    onEscalate()
                } label: {
                    Text("Escalate now")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.vertical, 10)
                }
            }
            .padding(.vertical, 40)
        }
        .onAppear {
            startTimer()
            feedback.notificationOccurred(.warning)
        }
        .onDisappear { stopTimer() }
    }

    private var progress: Double {
        1.0 - Double(secondsRemaining) / 30.0
    }

    private func startTimer() {
        secondsRemaining = 30
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                if secondsRemaining > 0 {
                    secondsRemaining -= 1
                    if secondsRemaining <= 5 {
                        feedback.notificationOccurred(.error)
                    }
                } else {
                    stopTimer()
                    onEscalate()
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

#Preview {
    FallAlertView(onCancel: {}, onEscalate: {})
}

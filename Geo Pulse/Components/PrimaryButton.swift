import SwiftUI

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var tone: Tone = .filled
    let action: () -> Void

    enum Tone {
        case filled, outlined
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(AppTypography.bodyBold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(tone == .filled ? Color.white : AppColors.primary)
            .background(tone == .filled ? AppColors.primary : AppColors.primarySoft)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

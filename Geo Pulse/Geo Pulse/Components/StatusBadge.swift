import SwiftUI

enum BadgeTone {
    case neutral, success, warning, danger, info

    var background: Color {
        switch self {
        case .neutral: return AppColors.surfaceAlt
        case .success: return AppColors.accentSuccessSoft
        case .warning: return AppColors.accentWarningSoft
        case .danger: return AppColors.accentDangerSoft
        case .info: return AppColors.primarySoft
        }
    }

    var foreground: Color {
        switch self {
        case .neutral: return AppColors.textSecondary
        case .success: return AppColors.accentSuccess
        case .warning: return AppColors.accentWarning
        case .danger: return AppColors.accentDanger
        case .info: return AppColors.primary
        }
    }
}

struct StatusBadge: View {
    let text: String
    var tone: BadgeTone = .neutral
    var showsDot: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            if showsDot {
                Circle()
                    .fill(tone.foreground)
                    .frame(width: 6, height: 6)
            }
            Text(text)
                .font(AppTypography.captionBold())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundStyle(tone.foreground)
        .background(tone.background)
        .clipShape(Capsule())
    }
}

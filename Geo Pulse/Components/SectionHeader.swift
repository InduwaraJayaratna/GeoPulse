import SwiftUI

struct SectionHeader: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(AppTypography.titleSmall())
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
            if let trailing = trailing {
                Text(trailing)
                    .font(AppTypography.caption())
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
    }
}

struct LabelCaps: View {
    let text: String
    var color: Color = AppColors.textTertiary

    var body: some View {
        Text(text.uppercased())
            .font(AppTypography.label())
            .tracking(0.8)
            .foregroundStyle(color)
    }
}

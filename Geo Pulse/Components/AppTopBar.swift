import SwiftUI

struct AppTopBar: View {
    let title: String
    var showsLogo: Bool = true
    var trailing: AnyView? = nil

    var body: some View {
        HStack {
            if showsLogo {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppColors.primary)
                            .frame(width: 32, height: 32)
                        Image(systemName: "scope")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Text("GeoPulse")
                        .font(AppTypography.bodyBold())
                        .foregroundStyle(AppColors.textPrimary)
                }
            }
            Spacer()
            Text(title)
                .font(AppTypography.titleSmall())
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
            if let trailing = trailing {
                trailing
            } else {
                ZStack {
                    Circle()
                        .fill(AppColors.primary)
                        .frame(width: 32, height: 32)
                    Image(systemName: "person.fill")
                        .foregroundStyle(.white)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}

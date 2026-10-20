import SwiftUI

struct CardContainer<Content: View>: View {
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 18
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
    }
}

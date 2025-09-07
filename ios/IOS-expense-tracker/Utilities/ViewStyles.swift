import SwiftUI

// Reusable card and tile styles to keep visuals consistent
struct CardStyle: ViewModifier {
    var cornerRadius: CGFloat = AppConfig.UI.cardCornerRadius
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(colorScheme == .dark ? .white.opacity(0.15) : .black.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
    }
}

extension View {
    func cardStyle(cornerRadius: CGFloat = AppConfig.UI.cardCornerRadius) -> some View {
        modifier(CardStyle(cornerRadius: cornerRadius))
    }
}


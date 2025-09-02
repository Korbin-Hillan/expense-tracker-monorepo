import SwiftUI

// Centralized brand palette
struct Palette {
    // Base brand colors (light mode defaults)
    private static let accentLight = Color(hex: "#6C5CE7")      // Indigo/Violet
    private static let accentSecondaryLight = Color(hex: "#00C2FF") // Cyan accent

    // Dark mode tweaks (slightly brighter/saturated)
    private static let accentDark = Color(hex: "#8B80FF")
    private static let accentSecondaryDark = Color(hex: "#2AD3FF")

    // Semantic colors (same across modes; easy to customize later)
    static let success = Color(hex: "#22C55E")
    static let warning = Color(hex: "#F59E0B")
    static let danger  = Color(hex: "#EF4444")
    static let info    = Color(hex: "#3B82F6")

    // Neutral overlays (used sparingly; most surfaces use material)
    static let surfaceStrokeLight = Color.black.opacity(0.06)
    static let surfaceStrokeDark  = Color.white.opacity(0.15)

    // Dynamic getters
    static func accent(for scheme: ColorScheme) -> Color {
        scheme == .dark ? accentDark : accentLight
    }

    static func accentSecondary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? accentSecondaryDark : accentSecondaryLight
    }
}

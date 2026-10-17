import SwiftUI

enum AppTypography {
    static func largeTitle() -> Font { .system(size: 32, weight: .bold, design: .default) }
    static func title() -> Font { .system(size: 22, weight: .semibold, design: .default) }
    static func titleSmall() -> Font { .system(size: 18, weight: .semibold, design: .default) }
    static func body() -> Font { .system(size: 16, weight: .regular, design: .default) }
    static func bodyBold() -> Font { .system(size: 16, weight: .semibold, design: .default) }
    static func caption() -> Font { .system(size: 13, weight: .regular, design: .default) }
    static func captionBold() -> Font { .system(size: 13, weight: .semibold, design: .default) }
    static func micro() -> Font { .system(size: 11, weight: .medium, design: .default) }
    static func label() -> Font { .system(size: 12, weight: .semibold, design: .default) }
}

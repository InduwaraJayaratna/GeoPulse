import SwiftUI

enum AppTypography {
    static func largeTitle() -> Font { .largeTitle.bold() }
    static func title() -> Font { .title2 }
    static func titleSmall() -> Font { .headline }
    static func body() -> Font { .body }
    static func bodyBold() -> Font { .body.bold() }
    static func caption() -> Font { .subheadline }
    static func captionBold() -> Font { .subheadline.bold() }
    static func micro() -> Font { .caption2 }
    static func label() -> Font { .caption }
}

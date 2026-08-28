import SwiftUI

/// Centralized layout tokens so spacing and corner radii are consistent across
/// the app instead of scattered magic numbers. Named to match `AppMotion` - /// the app's other design-system namespace.
///
/// The scale is an 8-pt rhythm with two finer steps (2, 4) for tight,
/// intra-component spacing (icon-to-label, stacked text).
enum AppSpacing {
    /// 2 - hairline gaps inside a component (e.g. title above subtitle).
    static let xxs: CGFloat = 2
    /// 4 - tight grouping.
    static let xs: CGFloat = 4
    /// 8 - related elements.
    static let sm: CGFloat = 8
    /// 12 - default control padding.
    static let md: CGFloat = 12
    /// 16 - content padding inside cards/rows.
    static let lg: CGFloat = 16
    /// 20 - comfortable horizontal control padding.
    static let xl: CGFloat = 20
    /// 24 - section spacing / screen gutters.
    static let xxl: CGFloat = 24
    /// 32 - major vertical rhythm.
    static let xxxl: CGFloat = 32
}

/// Corner radii. Continuous-curvature rounded rectangles are the iOS-native
/// look; pair these with `.rect(cornerRadius:)` or
/// `RoundedRectangle(cornerRadius:style:.continuous)`.
enum AppRadius {
    /// 8 - small chips / inline controls.
    static let sm: CGFloat = 8
    /// 12 - cards, glass controls (matches existing `.glassEffect` usage).
    static let md: CGFloat = 12
    /// 16 - prominent cards / tiles.
    static let lg: CGFloat = 16
    /// 20 - large surfaces.
    static let xl: CGFloat = 20
}

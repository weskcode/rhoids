import SwiftUI

enum AdaptiveLayout {
    /// Returns a timer font that scales with available width, capped at 72pt
    /// and floored at 44pt for accessibility minimums.
    static func timerFont(for width: CGFloat, dynamicTypeSize: DynamicTypeSize = .large) -> Font {
        let baseSize = min(max(width * 0.22, 44), 72)
        let size = baseSize * dynamicTypeSize.layoutScaleFactor
        return .system(size: size, weight: .thin, design: .rounded)
    }

    /// Returns an icon size that scales with container width, capped.
    static func iconSize(for width: CGFloat, maximum: CGFloat = 64) -> CGFloat {
        min(Swift.max(width * 0.18, 36), maximum)
    }

    /// Standard horizontal padding as a fraction of width, floored at 16pt.
    static func horizontalPadding(for width: CGFloat, fraction: CGFloat = 0.05) -> CGFloat {
        max(width * fraction, 16)
    }
}

extension DynamicTypeSize {
    /// Approximate layout scale factor relative to the default (.large) size.
    var layoutScaleFactor: CGFloat {
        switch self {
        case .xSmall:          return 0.82
        case .small:           return 0.88
        case .medium:          return 0.94
        case .large:           return 1.0
        case .xLarge:          return 1.12
        case .xxLarge:         return 1.23
        case .xxxLarge:        return 1.35
        case .accessibility1:  return 1.60
        case .accessibility2:  return 1.90
        case .accessibility3:  return 2.25
        case .accessibility4:  return 2.75
        case .accessibility5:  return 3.25
        @unknown default:      return 1.0
        }
    }
}

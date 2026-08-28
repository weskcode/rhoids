import SwiftUI

enum AppMotion {
    static func contextChange(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.16) : .smooth(duration: 0.44)
    }

    static func timerActivation(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.16) : .smooth(duration: 0.52)
    }

    static func timerCompletion(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.14) : .smooth(duration: 0.36)
    }

    static func reveal(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.14) : .smooth(duration: 0.28)
    }

    static func feedback(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .snappy(duration: 0.22)
    }

    static func optionSelection(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .smooth(duration: 0.24)
    }

    static func progress(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .linear(duration: 0.26)
    }

    static func digitFlip(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .smooth(duration: 0.18)
    }

    static func edgeFade(_ edge: Edge, reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }

        let distance: CGFloat = switch edge {
        case .top: -10
        case .bottom: 10
        case .leading: -10
        case .trailing: 10
        }

        if edge == .top || edge == .bottom {
            return .opacity.combined(with: .offset(y: distance))
        }
        return .opacity.combined(with: .offset(x: distance))
    }
}

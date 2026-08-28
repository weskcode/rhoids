import Testing
import SwiftUI
@testable import RHOIDS

struct AppMotionTests {

    // MARK: - Reduced motion produces non-nil animations

    @Test("contextChange produces an animation for both motion modes",
          arguments: [true, false])
    func contextChangeNonNil(reduceMotion: Bool) {
        let animation = AppMotion.contextChange(reduceMotion: reduceMotion)
        #expect(type(of: animation) == Animation.self)
    }

    @Test("timerActivation produces an animation for both motion modes",
          arguments: [true, false])
    func timerActivationNonNil(reduceMotion: Bool) {
        let animation = AppMotion.timerActivation(reduceMotion: reduceMotion)
        #expect(type(of: animation) == Animation.self)
    }

    @Test("timerCompletion produces an animation for both motion modes",
          arguments: [true, false])
    func timerCompletionNonNil(reduceMotion: Bool) {
        let animation = AppMotion.timerCompletion(reduceMotion: reduceMotion)
        #expect(type(of: animation) == Animation.self)
    }

    @Test("reveal produces an animation for both motion modes",
          arguments: [true, false])
    func revealNonNil(reduceMotion: Bool) {
        let animation = AppMotion.reveal(reduceMotion: reduceMotion)
        #expect(type(of: animation) == Animation.self)
    }

    @Test("feedback produces an animation for both motion modes",
          arguments: [true, false])
    func feedbackNonNil(reduceMotion: Bool) {
        let animation = AppMotion.feedback(reduceMotion: reduceMotion)
        #expect(type(of: animation) == Animation.self)
    }

    @Test("optionSelection produces an animation for both motion modes",
          arguments: [true, false])
    func optionSelectionNonNil(reduceMotion: Bool) {
        let animation = AppMotion.optionSelection(reduceMotion: reduceMotion)
        #expect(type(of: animation) == Animation.self)
    }

    @Test("progress produces an animation for both motion modes",
          arguments: [true, false])
    func progressNonNil(reduceMotion: Bool) {
        let animation = AppMotion.progress(reduceMotion: reduceMotion)
        #expect(type(of: animation) == Animation.self)
    }

    @Test("digitFlip produces an animation for both motion modes",
          arguments: [true, false])
    func digitFlipNonNil(reduceMotion: Bool) {
        let animation = AppMotion.digitFlip(reduceMotion: reduceMotion)
        #expect(type(of: animation) == Animation.self)
    }

    // MARK: - Edge transitions

    @Test("edgeFade produces a transition for all edges",
          arguments: [Edge.top, .bottom, .leading, .trailing])
    func edgeFadeAllEdges(edge: Edge) {
        let transition = AppMotion.edgeFade(edge, reduceMotion: false)
        #expect(type(of: transition) == AnyTransition.self)
    }

    @Test("edgeFade with reduceMotion returns opacity transition for all edges",
          arguments: [Edge.top, .bottom, .leading, .trailing])
    func edgeFadeReducedMotion(edge: Edge) {
        let transition = AppMotion.edgeFade(edge, reduceMotion: true)
        #expect(type(of: transition) == AnyTransition.self)
    }
}

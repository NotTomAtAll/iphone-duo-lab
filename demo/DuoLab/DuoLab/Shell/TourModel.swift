import Foundation
import Observation
import UIKit
import UIKit.UIGestureRecognizerSubclass
import SwiftUI

/// How the guided tour starts: from the Topics button, `duolab://tour` or `-tour 1`.
struct TourLaunch: Equatable {
    /// 1-based, like the "n/N" the strip shows.
    var step = 1
    var paused = false
    var compare = false
}

/// Topics that are built (stubs still say "Coming soon"), in catalog order.
extension LabID {
    static var catalog: [LabID] { allCases.filter { $0.options.first?.id != "placeholder" } }
}

/// One tour stop: a topic, its recommended answer, and the first answer to avoid, if any.
struct TourStep: Identifiable {
    let lab: LabID
    let option: LabOption
    let avoid: LabOption?

    var id: String { lab.rawValue }

    init(lab: LabID) {
        self.lab = lab
        option = lab.featuredOption
        avoid = lab.options.first { $0.verdict == .avoid }
    }

    static let all: [TourStep] = LabID.catalog.map { TourStep(lab: $0) }

    /// The whole tour at its own pace, rounded to whole minutes, for the copy that invites to it.
    static var minutes: Int { max(1, Int((Double(all.count) * TourModel.stepDuration / 60).rounded())) }
}

/// The tour's clock: which step, how far into it, and whether it is held.
/// Runs only when not paused by the user, not held by a recent touch, and Reduce Motion is off.
@Observable
final class TourModel {
    static let stepDuration: Double = 8
    static let idleResume: TimeInterval = 5

    let steps: [TourStep]
    private(set) var index: Int
    /// Paused with the button (or by reaching the end). A touch only holds the clock for a while.
    private(set) var userPaused: Bool
    var compare: Bool
    /// Seconds into the current step.
    private(set) var elapsed: Double = 0
    private(set) var holdUntil = Date.distantPast
    /// The direction of the last step change, for the caption's slide.
    private(set) var forward = true

    init(launch: TourLaunch, steps: [TourStep] = TourStep.all) {
        self.steps = steps
        index = min(max(launch.step - 1, 0), max(steps.count - 1, 0))
        userPaused = launch.paused
        compare = launch.compare
    }

    var step: TourStep { steps[index] }
    var isFirst: Bool { index == 0 }
    var isLast: Bool { index == steps.count - 1 }
    var progress: Double { elapsed / Self.stepDuration }

    func isRunning(now: Date = .now, reduceMotion: Bool) -> Bool {
        !userPaused && !reduceMotion && now >= holdUntil
    }

    /// Any touch holds the clock; it picks up again after `idleResume` seconds without one.
    func touched(now: Date = .now) {
        holdUntil = now.addingTimeInterval(Self.idleResume)
    }

    /// Moves the clock on. Returns true when it is time to show the next step.
    /// The last step stops the clock instead of looping.
    func tick(_ seconds: Double, now: Date = .now, reduceMotion: Bool) -> Bool {
        guard isRunning(now: now, reduceMotion: reduceMotion) else { return false }
        // Small slack: eighty 0.1 s ticks add up to a hair under 8.
        elapsed = min(elapsed + seconds, Self.stepDuration)
        if elapsed > Self.stepDuration - 0.001 { elapsed = Self.stepDuration }
        guard elapsed >= Self.stepDuration else { return false }
        if isLast {
            userPaused = true
            return false
        }
        return true
    }

    func go(_ delta: Int) {
        let next = min(max(index + delta, 0), steps.count - 1)
        guard next != index else { return }
        forward = next > index
        index = next
        elapsed = 0
    }

    /// Play starts right away (no idle hold); at the very end it starts over.
    func togglePlay() {
        if userPaused {
            if isLast, elapsed >= Self.stepDuration { go(-index) }
            userPaused = false
            holdUntil = .distantPast
        } else {
            userPaused = true
        }
    }
}

/// Reports every touch that lands anywhere under it, without taking part in gestures:
/// the recognizer fails on the first touch, so scrolling and buttons work as usual.
struct TouchWatcher: UIGestureRecognizerRepresentable {
    var onTouch: () -> Void

    func makeUIGestureRecognizer(context: Context) -> TouchDownRecognizer {
        let recognizer = TouchDownRecognizer(target: nil, action: nil)
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false
        recognizer.onTouch = onTouch
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: TouchDownRecognizer, context: Context) {
        recognizer.onTouch = onTouch
    }
}

final class TouchDownRecognizer: UIGestureRecognizer {
    var onTouch: () -> Void = {}

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        onTouch()
        state = .failed
    }
}

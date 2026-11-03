import Foundation
import Observation
import SwiftUI

/// An option opened full screen, with optional knob overrides from a link.
struct PreviewTarget: Identifiable, Hashable {
    let lab: LabID
    let optionID: String
    var knobs: [String: String] = [:]
    var entrance: PreviewEntrance = .system

    var id: String { "\(lab.rawValue)/\(optionID)" }
}

/// How an opened option arrives and leaves.
enum PreviewEntrance: Hashable {
    /// The card grows into the screen. Only when its picture is of the display the user is on,
    /// so the first and last frames of the morph are the same picture.
    case zoom
    /// A quick fade and settle, when the card shows the other display (a wide picture cannot
    /// morph into a tall screen without looking wrong).
    case fade
    /// The default cover slide.
    case system
    /// Opened by a link or launch arguments: drawn straight in the root view, with no cover.
    /// A cover presented during launch (before the scene is active) keeps UIKit dropping every
    /// touch until its presentation completes, which left the whole screen dead for ~1 s after the
    /// first frame. Without a presentation the screen takes touches from its first frame.
    case linked

    /// Whether this arrival is presented in a full-screen cover (everything but `.linked`).
    var usesCover: Bool { self != .linked }
}

/// App-wide navigation.
@Observable
final class AppRouter {
    var tab: RootTab = .topics
    var path: [LabID] = []
    var preview: PreviewTarget?
    /// The measuring overlay (safe area, fold, cameras, readout).
    var measure = false
    var banner: String?
    /// The last hinge reading the app saw. `onHingeChange` only fires on a change, so a view
    /// created later (stepping ‹ › re-creates the lab) seeds itself from this instead of
    /// starting at "waiting". Kept current from the root, see `DuoChrome`.
    var hinge = HingeReading.unknown
    /// The guided tour, while it is up.
    var tour: TourLaunch?
    /// Where to go once the tour's cover has gone ("Open this topic").
    private(set) var afterTour: PreviewTarget?

    private var bannerTask: Task<Void, Never>?

    /// Starts the tour at a valid step. Returns a problem to show when the step was out of range.
    @discardableResult
    func startTour(_ launch: TourLaunch = TourLaunch()) -> String? {
        var launch = launch
        let count = TourStep.all.count
        var problem: String?
        if launch.step > count {
            problem = "The tour has \(count) steps"
            launch.step = count
        }
        launch.step = max(1, launch.step)
        afterTour = nil
        if preview?.entrance == .linked {
            // Drawn in the root, not a cover: nothing to wait for.
            preview = nil
            tour = launch
        } else if preview != nil {
            // One cover at a time: let the option screen go first.
            preview = nil
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(600))
                self?.tour = launch
            }
        } else {
            tour = launch
        }
        return problem
    }

    /// Closes the tour; with a target, that option opens once the tour has gone.
    func closeTour(opening target: PreviewTarget? = nil) {
        afterTour = target
        tour = nil
    }

    /// Called when the tour's cover has finished leaving. Returns the option to open, if any,
    /// with its topic already chosen.
    func takeTourExit() -> PreviewTarget? {
        guard let target = afterTour else { return nil }
        afterTour = nil
        openTopic(target.lab)
        return target
    }

    func openTopic(_ lab: LabID) {
        tab = .topics
        path = [lab]
    }

    func preview(_ option: LabOption, in lab: LabID) {
        preview = PreviewTarget(lab: lab, optionID: option.id)
    }

    func handle(_ link: DeepLink) {
        var problems = link.errors
        if let measure = link.measure { self.measure = measure }
        if let tab = link.tab { self.tab = tab }
        if let lab = link.lab {
            // A link lands without any transition: no push animation and no cover slide. Any
            // presentation still in flight makes UIKit drop touches, so an animated arrival (push
            // under the cover's slide, slower still while the first thumbnails render) left the
            // lab bar ignoring taps right when a shared link is first opened.
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) {
                path = [lab]
                if let optionID = link.option {
                    if let option = lab.option(optionID) {
                        let preset = KnobState(lab: lab, values: option.knobs)
                        problems += preset.apply(link.knobs)
                        preview = PreviewTarget(lab: lab, optionID: option.id, knobs: link.knobs, entrance: .linked)
                        // The option is drawn under any cover; a tour cover would hide it.
                        if link.tour == nil, tour != nil { closeTour() }
                    } else {
                        problems.append("\(lab.title) has no option “\(optionID)”")
                    }
                } else if !link.knobs.isEmpty {
                    problems.append("Knob values need an option")
                }
            }
        }
        if let tour = link.tour, let problem = startTour(tour) { problems.append(problem) }
        if !problems.isEmpty { show(banner: problems.joined(separator: "\n")) }
    }

    func show(banner text: String) {
        banner = text
        bannerTask?.cancel()
        bannerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.banner = nil
        }
    }
}

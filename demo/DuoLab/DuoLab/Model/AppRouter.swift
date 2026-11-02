import Foundation
import Observation

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
    /// The default cover slide, for deep links that have no card to come from.
    case system
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

    private var bannerTask: Task<Void, Never>?

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
            path = [lab]
            if let optionID = link.option {
                if let option = lab.option(optionID) {
                    let preset = KnobState(lab: lab, values: option.knobs)
                    problems += preset.apply(link.knobs)
                    preview = PreviewTarget(lab: lab, optionID: option.id, knobs: link.knobs)
                } else {
                    problems.append("\(lab.title) has no option “\(optionID)”")
                }
            } else if !link.knobs.isEmpty {
                problems.append("Knob values need an option")
            }
        }
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

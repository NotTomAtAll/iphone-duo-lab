import Foundation
import Observation

/// An option opened full screen, with optional knob overrides from a link.
struct PreviewTarget: Identifiable, Hashable {
    let lab: LabID
    let optionID: String
    var knobs: [String: String] = [:]

    var id: String { "\(lab.rawValue)/\(optionID)" }
}

/// App-wide navigation.
@Observable
final class AppRouter {
    var tab: RootTab = .topics
    /// A topic the gallery should scroll to.
    var focusedTopic: LabID?
    var preview: PreviewTarget?
    /// The measuring overlay (safe area, fold, cameras, readout).
    var measure = false
    var banner: String?

    private var bannerTask: Task<Void, Never>?

    func openTopic(_ lab: LabID) {
        tab = .topics
        focusedTopic = lab
    }

    func preview(_ option: LabOption, in lab: LabID) {
        preview = PreviewTarget(lab: lab, optionID: option.id)
    }

    func handle(_ link: DeepLink) {
        var problems = link.errors
        if let measure = link.measure { self.measure = measure }
        if let tab = link.tab { self.tab = tab }
        if let lab = link.lab {
            focusedTopic = lab
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

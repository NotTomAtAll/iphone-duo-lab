import SwiftUI

/// How an option stands against Apple's guidance.
enum Verdict: String, Codable, Sendable, CaseIterable {
    case recommended, consider, avoid, system, effect

    var title: String {
        switch self {
        case .recommended: "Recommended"
        case .consider: "Worth a try"
        case .avoid: "Avoid"
        case .system: "Built in"
        case .effect: "Effect"
        }
    }

    var symbol: String {
        switch self {
        case .recommended: "checkmark.seal.fill"
        case .consider: "circle.lefthalf.filled"
        case .avoid: "xmark.octagon.fill"
        case .system: "gearshape.fill"
        case .effect: "sparkles"
        }
    }

    var color: Color {
        switch self {
        case .recommended: .green
        case .consider: .blue
        case .avoid: .red
        case .system: .gray
        case .effect: .purple
        }
    }
}

/// One concrete answer to a topic's question: a preset of knob values plus the reasoning.
struct LabOption: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let verdict: Verdict
    /// One sentence: what this option is.
    let summary: String
    let pros: [String]
    let cons: [String]
    /// What to try on the device to judge it.
    let lookFor: String
    /// Knob values that differ from the lab's defaults.
    let knobs: [String: String]
    /// A knob worth flipping right in the preview bar (e.g. broken / fixed).
    let highlight: String?

    init(_ id: String, _ title: String, _ verdict: Verdict, summary: String,
         pros: [String] = [], cons: [String] = [], lookFor: String,
         knobs: [String: String] = [:], highlight: String? = nil) {
        self.id = id
        self.title = title
        self.verdict = verdict
        self.summary = summary
        self.pros = pros
        self.cons = cons
        self.lookFor = lookFor
        self.knobs = knobs
        self.highlight = highlight
    }
}

extension LabID {
    var options: [LabOption] {
        switch self {
        case .tabBar: TabBarLab.options
        case .toolbars: ToolbarsLab.options
        case .listDetail: ListDetailLab.options
        case .grids: GridsLab.options
        case .reading: ReadingLab.options
        case .media: MediaLab.options
        case .overlays: OverlaysLab.options
        case .sheets: SheetsLab.options
        case .hinge: HingeLab.options
        case .antiPatterns: AntiPatternsLab.options
        case .continuity: ContinuityLab.options
        case .laptopPose: LaptopPoseLab.options
        case .motion: MotionLab.options
        case .toasts: ToastsLab.options
        case .twoPanes: TwoPanesLab.options
        case .keyboard: KeyboardLab.options
        case .transitions: TransitionsLab.options
        }
    }

    func option(_ id: String) -> LabOption? { options.first { $0.id == id } }

    /// The option shown on the topic card when nothing is chosen yet.
    var featuredOption: LabOption {
        options.first { $0.verdict == .recommended } ?? options[0]
    }

    /// Apple's position on the topic, in one or two sentences.
    var guidance: String {
        switch self {
        case .tabBar: "Use the standard tab bar. It adapts to every pose on its own; a tab bar the app draws itself does not."
        case .toolbars: "Standard bars move to the side of the screen when that fits better. Bars the app draws itself stay put."
        case .listDetail: "Use the big display to show more at once, not a stretched copy of the phone layout."
        case .grids: "Let layouts flow with the width, prefer an even number of columns, and keep buttons off the fold."
        case .reading: "A readable column suits long text and forms. Everything else should use the width."
        case .media: "Place the main view and its companion on either side of the fold, and stack them when folded."
        case .overlays: "Standard sheets and menus avoid the fold on their own. Anything the app floats itself has to do it by hand."
        case .sheets: "Sheets, alerts and menus find a spot clear of the fold and the cameras on their own."
        case .hinge: "Use the hinge angle for delightful effects, never to decide the layout."
        case .antiPatterns: "Base layout on the space you actually have, never on the screen size, orientation or values saved at launch."
        case .continuity: "Keep functionality and the state of every element the same between displays. People open and close the device often."
        case .laptopPose: "When the device is half open on a surface, put media at the top and tappable controls at the bottom, and keep the same controls in every pose."
        case .motion: "Animate the switch between layouts, not every frame of the resize. Respect Reduce Motion."
        case .toasts: "Apple ships no toast. Prefer showing the change itself; a short message belongs in the pane the action came from, clear of the fold and the side rail."
        case .twoPanes: "Use the extra space for a second level of hierarchy or a companion pane, and let people move things between the two halves."
        case .keyboard: "Keep the field you are typing in visible above the keyboard in every pose, and keep the keyboard up across a fold."
        case .transitions: "Use the system transitions: zoom from the thing you tapped, and plain pushes. Keep them short on the big display."
        }
    }

    var shortTitle: String {
        switch self {
        case .tabBar: "Tab bar"
        case .toolbars: "Toolbars"
        case .listDetail: "List & detail"
        case .grids: "Grids"
        case .reading: "Reading width"
        case .media: "Media"
        case .overlays: "Overlays"
        case .sheets: "Presentations"
        case .hinge: "Hinge"
        case .antiPatterns: "Pitfalls"
        case .continuity: "Continuity"
        case .laptopPose: "Laptop pose"
        case .motion: "Motion"
        case .toasts: "Toasts"
        case .twoPanes: "Two panes"
        case .keyboard: "Keyboard"
        case .transitions: "Transitions"
        }
    }
}

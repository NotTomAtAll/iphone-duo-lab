import SwiftUI

// STUB: to be built. See docs/07-lab-backlog.md.
enum TwoPanesLab {
    static let options: [LabOption] = [
        LabOption("placeholder", "Coming soon", .consider, summary: "This topic is being built.", lookFor: "Nothing yet."),
    ]

    static let knobs: [KnobSpec] = [
        .toggle("placeholder", "Placeholder", note: "To be replaced."),
    ]
}

struct TwoPanesLabView: View {
    let state: KnobState

    var body: some View {
        ContentUnavailableView("Two panes and drag", systemImage: "rectangle.split.2x1", description: Text("Being built."))
    }
}

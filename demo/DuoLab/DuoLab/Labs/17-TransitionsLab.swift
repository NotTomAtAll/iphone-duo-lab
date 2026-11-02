import SwiftUI

// STUB: to be built. See docs/07-lab-backlog.md.
enum TransitionsLab {
    static let options: [LabOption] = [
        LabOption("placeholder", "Coming soon", .consider, summary: "This topic is being built.", lookFor: "Nothing yet."),
    ]

    static let knobs: [KnobSpec] = [
        .toggle("placeholder", "Placeholder", note: "To be replaced."),
    ]
}

struct TransitionsLabView: View {
    let state: KnobState

    var body: some View {
        ContentUnavailableView("Transitions", systemImage: "arrow.up.left.and.arrow.down.right", description: Text("Being built."))
    }
}

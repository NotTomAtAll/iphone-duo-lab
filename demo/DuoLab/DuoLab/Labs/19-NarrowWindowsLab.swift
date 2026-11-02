import SwiftUI

// STUB: to be built. See docs/07-lab-backlog.md.
enum NarrowWindowsLab {
    static let options: [LabOption] = [
        LabOption("placeholder", "Coming soon", .consider, summary: "This topic is being built.", lookFor: "Nothing yet."),
    ]

    static let knobs: [KnobSpec] = [
        .toggle("placeholder", "Placeholder", note: "To be replaced."),
    ]
}

struct NarrowWindowsLabView: View {
    let state: KnobState

    var body: some View {
        ContentUnavailableView("Small windows", systemImage: "rectangle.compress.vertical", description: Text("Being built."))
    }
}

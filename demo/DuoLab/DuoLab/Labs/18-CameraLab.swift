import SwiftUI

// STUB: to be built. See docs/07-lab-backlog.md.
enum CameraLab {
    static let options: [LabOption] = [
        LabOption("placeholder", "Coming soon", .consider, summary: "This topic is being built.", lookFor: "Nothing yet."),
    ]

    static let knobs: [KnobSpec] = [
        .toggle("placeholder", "Placeholder", note: "To be replaced."),
    ]
}

struct CameraLabView: View {
    let state: KnobState

    var body: some View {
        ContentUnavailableView("Camera per pose", systemImage: "camera", description: Text("Being built."))
    }
}

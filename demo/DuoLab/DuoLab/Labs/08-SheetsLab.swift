import SwiftUI

enum SheetsLab {
    static let options: [LabOption] = [
        LabOption("sheet-form", "Form sheet", .system,
                  summary: "A card in the middle of the open display; a bottom sheet when folded.",
                  pros: ["Keeps context visible around it"], cons: [],
                  lookFor: "Open from each button: the card stays clear of the fold.",
                  knobs: ["kind": "sheet", "sizing": "form"]),
        LabOption("sheet-page", "Page sheet", .system,
                  summary: "A wider card, close to full screen.",
                  pros: ["Room for richer content"], cons: ["Covers more of the screen"],
                  lookFor: "Width compared to the form sheet.",
                  knobs: ["kind": "sheet", "sizing": "page"]),
        LabOption("popover", "Popover", .system,
                  summary: "A bubble that points at the button that opened it.",
                  pros: ["Stays next to its source"], cons: ["Can point across the fold"],
                  lookFor: "Open from the center button in book pose.",
                  knobs: ["kind": "popover"]),
        LabOption("alert", "Alert", .system,
                  summary: "A small message box in the middle of the screen.",
                  pros: ["The system moves it off the fold"], cons: [],
                  lookFor: "Where it sits in book pose.",
                  knobs: ["kind": "alert"]),
        LabOption("dialog", "Confirmation dialog", .system,
                  summary: "A short list of actions to pick from.",
                  pros: ["Adapts its form by size class"], cons: [],
                  lookFor: "Its shape on each display.",
                  knobs: ["kind": "dialog"]),
        LabOption("menu", "Menu", .system,
                  summary: "A list that drops down from a button.",
                  pros: ["Lightweight, stays near the button"], cons: [],
                  lookFor: "Open the trailing menu next to the rail.",
                  knobs: ["kind": "menu"]),
        LabOption("sheet-trailing-half", "Sheet in the right half", .recommended,
                  summary: "On the open display the sheet sits on the right, next to the part it edits, and the left half stays usable.",
                  pros: ["Sits next to the content it changes", "The other half stays visible and tappable",
                         "Gets the side bar for its buttons"],
                  cons: ["Folded it is a normal bottom sheet, so check both"],
                  lookFor: "Open it in book pose: the card should stay in the right half, clear of the fold. Tap the left half while it is open.",
                  knobs: ["kind": "sheet", "sizing": "form", "placement": "trailing", "interact": "on"]),
        LabOption("sheet-centered", "Card asked to sit in the middle", .system,
                  summary: "The standard card, asked to sit in the middle. Fully open it is centered; in book pose the system moves it into the left half by itself.",
                  pros: ["The default most people expect", "The system keeps it off the fold in book pose"],
                  cons: ["In book pose it lands in the left half even though you asked for the middle"],
                  lookFor: "Open it fully open, then in book pose: it moves from the middle to the left half.",
                  knobs: ["kind": "sheet", "sizing": "form", "placement": "center"]),
        LabOption("sheet-full-width", "Cover across the whole display", .avoid,
                  summary: "iOS will not stretch a sheet across the fold, so the nearest thing is a full-screen cover: it hides everything, fold included.",
                  pros: ["Most room for content"],
                  cons: ["Hides everything behind it", "Text and controls run across the fold in book pose",
                         "Apple advises against presentations that cover most of the window"],
                  lookFor: "Open it in book pose: rows and the title run over the fold.",
                  knobs: ["kind": "fullScreen"]),
    ]

    static let knobs: [KnobSpec] = [
        KnobSpec("kind", "Presentation", options: [
            .init("sheet", "Sheet"), .init("popover", "Popover"), .init("alert", "Alert"),
            .init("dialog", "Confirmation dialog"), .init("menu", "Menu"), .init("fullScreen", "Full-screen cover"),
        ], note: "HIG: system sheets, alerts and menus move aside from the fold by themselves. Try each from a button on the left, middle and right.",
        facts: ["F-6b"]),
        KnobSpec("detents", "Sheet detents", options: [
            .init("large", "Large"), .init("medium", "Medium"), .init("both", "Medium + large"), .init("fraction", "30%"),
        ], default: "both",
        note: "Detents are heights. On the inner display a sheet is a centered card, so detents matter less there.",
        facts: []),
        KnobSpec("sizing", "Sheet sizing", options: [
            .init("automatic", "Automatic"), .init("form", "Form"), .init("page", "Page"), .init("fitted", "Fitted"),
        ], note: "presentationSizing picks the card size in regular width. Form is narrower; page is wider. In book pose every size is kept in one half.",
        facts: ["F-2b"]),
        KnobSpec("placement", "Sheet placement", options: [
            .init("automatic", "Automatic"), .init("leading", "Leading"), .init("center", "Center"), .init("trailing", "Trailing"),
        ], note: "New in iOS 27: a sheet can sit on the leading or trailing edge of the open display. Put it next to what it changes.",
        facts: []),
        .toggle("interact", "Use the screen behind",
                note: "Lets people keep tapping and scrolling the content behind the sheet.", facts: []),
    ]
}

struct SheetsLabView: View {
    let state: KnobState
    @State private var sheet = false
    @State private var fullScreen = false
    @State private var alert = false
    @State private var dialog = false
    @State private var popoverAnchor: Int?
    @Environment(\.isThumbnail) private var isThumbnail

    var body: some View {
        content
            .overlay {
                if isThumbnail {
                    PresentationMock(kind: state["kind"], sizing: state["sizing"], placement: state["placement"])
                }
            }
    }

    private var content: some View {
        NavigationStack {
            Color.clear.frame(height: 0)
                .task {
                    // `-duolab.present 1` opens the presentation once, for captures.
                    guard !isThumbnail, UserDefaults.standard.bool(forKey: "duolab.present") else { return }
                    try? await Task.sleep(for: .milliseconds(600))
                    present(1)
                }
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text(kindTitle).font(.largeTitle.bold())
                    Text(kindExplainer)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 520)
                }
                if !isAnchored {
                    Button("Show \(kindTitle.lowercased())", systemImage: "rectangle.portrait.on.rectangle.portrait") { present(1) }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                // Popovers and menus point at their button, so open them from each edge:
                // beside the leading edge, on the fold, and next to the trailing rail.
                if isAnchored {
                    HStack {
                        trigger(0)
                        Spacer()
                        trigger(1)
                        Spacer()
                        trigger(2)
                    }
                    .padding(.bottom, 24)
                }
            }
            .padding()
            .navigationTitle("Presentations")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $sheet) { sizedSheet }
        .fullScreenCover(isPresented: $fullScreen) { SheetBody(title: "Full-screen cover") }
        .alert("Delete draft?", isPresented: $alert) {
            Button("Delete", role: .destructive) {}
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Alerts move off the fold on their own.")
        }
        .confirmationDialog("Share to", isPresented: $dialog, titleVisibility: .visible) {
            Button("Messages") {}
            Button("Mail") {}
            Button("Copy link") {}
        }
    }

    /// Only popovers and menus depend on where they are opened from.
    private var isAnchored: Bool { state["kind"] == "popover" || state["kind"] == "menu" }

    private var kindTitle: String {
        switch state["kind"] {
        case "popover": "Popover"
        case "alert": "Alert"
        case "dialog": "Confirmation dialog"
        case "menu": "Menu"
        case "fullScreen": "Full-screen cover"
        default:
            switch state["sizing"] {
            case "page": "Page sheet"
            case "form": state["placement"] == "trailing" ? "Side sheet" : "Form sheet"
            default: "Sheet"
            }
        }
    }

    private var kindExplainer: String {
        switch state["kind"] {
        case "popover": "A bubble pointing at the button that opened it. Try the buttons at the left edge, on the fold and by the rail."
        case "alert": "A small centered box. The system keeps it clear of the fold."
        case "dialog": "A list of actions. It's an action sheet when folded and a floating card when open."
        case "menu": "A list that drops from its button. Try the buttons at the left edge, on the fold and by the rail."
        case "fullScreen": "Covers everything. Use it only for focused tasks."
        default:
            switch (state["sizing"], state["placement"]) {
            case ("page", _): "A wide card on the open display, almost full screen when folded."
            case (_, "trailing"): "A card on the right side of the open display; the left side stays usable. A bottom sheet when folded."
            case (_, "leading"): "A card on the left side of the open display. A bottom sheet when folded."
            default: "A narrower centered card on the open display, a bottom sheet when folded."
            }
        }
    }

    @ViewBuilder
    private func trigger(_ index: Int) -> some View {
        let title = ["Left edge", "Middle", "Right edge"][index % 3]
        if state["kind"] == "menu" {
            Menu {
                Button("Rename", systemImage: "pencil") {}
                Button("Duplicate", systemImage: "plus.square.on.square") {}
                Divider()
                Button("Delete", systemImage: "trash", role: .destructive) {}
            } label: {
                Label(title, systemImage: "ellipsis.circle")
            }
            .buttonStyle(.glass)
        } else {
            Button(title, systemImage: "rectangle.portrait.on.rectangle.portrait") { present(index) }
                .buttonStyle(.glass)
                .popover(isPresented: Binding(get: { popoverAnchor == index }, set: { if !$0 { popoverAnchor = nil } })) {
                    SheetBody(title: "Popover from \(title.lowercased())")
                        .frame(minWidth: 280, minHeight: 240)
                        .presentationCompactAdaptation(.popover)
                }
        }
    }

    private func present(_ index: Int) {
        switch state["kind"] {
        case "popover": popoverAnchor = index
        case "alert": alert = true
        case "dialog": dialog = true
        case "fullScreen": fullScreen = true
        default: sheet = true
        }
    }

    @ViewBuilder
    private var sizedSheet: some View {
        let body = SheetBody(title: kindTitle)
            .presentationDetents(detents)
            .presentationPlacement(placement)
            .presentationBackgroundInteraction(state.isOn("interact") ? .enabled : .automatic)
        switch state["sizing"] {
        case "form": body.presentationSizing(.form)
        case "page": body.presentationSizing(.page)
        case "fitted": body.presentationSizing(.fitted)
        default: body
        }
    }

    private var placement: PresentationPlacement {
        switch state["placement"] {
        case "leading": .leading
        case "center": .center
        case "trailing": .trailing
        default: .automatic
        }
    }

    private var detents: Set<PresentationDetent> {
        switch state["detents"] {
        case "large": [.large]
        case "medium": [.medium]
        case "fraction": [.fraction(0.3)]
        default: [.medium, .large]
        }
    }
}

private struct SheetBody: View {
    let title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(0..<8, id: \.self) { Text(Placeholder.name($0)) }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
    }
}

/// A static picture of the presentation, for thumbnails (real presentations can't render off-screen).
private struct PresentationMock: View {
    let kind: String
    let sizing: String
    var placement = "automatic"

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                if kind != "menu" && kind != "popover" && placement != "trailing" { Color.black.opacity(0.25) }
                switch kind {
                case "popover":
                    card(width: 300, height: 240).position(x: size.width / 2, y: 120 + 150)
                case "alert":
                    card(width: 280, height: 150, radius: 28).position(x: size.width / 2, y: size.height / 2)
                case "dialog":
                    card(width: min(size.width - 32, 420), height: 230).position(x: size.width / 2, y: size.height - 140)
                case "menu":
                    card(width: 220, height: 190).position(x: size.width - 140, y: 210)
                case "fullScreen":
                    card(width: size.width, height: size.height, radius: 0)
                default:
                    let wide = size.width > 600
                    let width: CGFloat = switch sizing {
                    case "page": min(size.width - 40, 760)
                    default: wide && placement == "trailing" || wide && placement == "leading"
                        ? min(size.width / 2 - 40, 400) : min(size.width - 40, 560)
                    }
                    let height: CGFloat = wide ? size.height - 80 : size.height * 0.55
                    let x: CGFloat = switch (wide, placement) {
                    case (true, "trailing"): size.width - width / 2 - 20 - min(84, size.width * 0.09)
                    case (true, "leading"): width / 2 + 20
                    default: size.width / 2
                    }
                    card(width: width, height: height, radius: 26)
                        .position(x: x, y: wide ? size.height / 2 : size.height - height / 2)
                }
            }
        }
    }

    private func card(width: CGFloat, height: CGFloat, radius: CGFloat = 18) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(.background)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 10) {
                    Capsule().fill(.secondary.opacity(0.4)).frame(width: 90, height: 10)
                    ForEach(0..<4, id: \.self) { _ in
                        Capsule().fill(.secondary.opacity(0.18)).frame(height: 10)
                    }
                }
                .padding(22)
            }
            .frame(width: width, height: height)
            .shadow(color: .black.opacity(0.2), radius: 20, y: 6)
    }
}

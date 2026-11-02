import SwiftUI

enum MotionLab {
    static let options: [LabOption] = [
        LabOption("mode", "Animate the layout switch only", .recommended,
                  summary: "Only the jump from one column to two panes animates. The grid simply refills, and the floating button glides to its new spot.",
                  pros: ["Calm: one clear movement per fold", "The eye can follow the button", "A second fold mid-way just turns it around"],
                  cons: ["Takes a little care to separate the switch from the resize"],
                  lookFor: "Open the device: the list slides to the side, the tiles fade into more columns, the button moves off the fold.",
                  knobs: ["motion": "mode"], highlight: "trigger"),
        LabOption("none", "No animation", .consider,
                  summary: "The new layout just appears.",
                  pros: ["Honest and instant", "Nothing can look wrong mid-way"],
                  cons: ["Hard to tell where the floating button went"],
                  lookFor: "Open the device and look for the button: it is suddenly somewhere else.",
                  knobs: ["motion": "none"], highlight: "trigger"),
        LabOption("everything", "Animate every size change", .avoid,
                  summary: "Everything that changes size or position animates, including the in-between sizes a fold passes through.",
                  pros: ["One line to add"],
                  cons: ["Tiles fly across the screen to new columns", "Animates through odd sizes while the device settles", "Feels slow on something people do all day"],
                  lookFor: "Open the device: tiles swoop to new places and the panes wobble before settling.",
                  knobs: ["motion": "everything"], highlight: "trigger"),
        LabOption("reduce", "Reduce Motion: crossfade", .system,
                  summary: "With Reduce Motion on, the recommended option fades between layouts instead of moving anything.",
                  pros: ["Respects the setting", "Still marks that the layout changed"],
                  cons: ["The button's path is lost; it fades out and back in"],
                  lookFor: "Fold or tap the switch: the old layout fades into the new one, nothing slides.",
                  knobs: ["motion": "reduce"], highlight: "trigger"),
    ]

    static let knobs: [KnobSpec] = [
        KnobSpec("motion", "Motion", options: [
            .init("mode", "Layout switch only"), .init("none", "None"),
            .init("everything", "Every size change"), .init("reduce", "Crossfade"),
        ], note: "Apple is silent on fold motion. A fold delivers in-between sizes before it settles, so animating raw size animates through them. Honour Reduce Motion.",
        facts: ["F-3e"]),
        KnobSpec("trigger", "Trigger", options: [.init("fold", "Fold"), .init("simulate", "Button")],
                 note: "Fold uses the real display change. Button flips the layout in place so you can watch it without folding.",
                 facts: []),
    ]
}

private enum MotionLayout: Equatable { case stacked, split }

struct MotionLabView: View {
    let state: KnobState
    @Environment(\.horizontalSizeClass) private var real
    @Environment(\.isThumbnail) private var isThumbnail
    @State private var simulatedWide: Bool?

    var body: some View {
        let simulate = state["trigger"] == "simulate"
        // Thumbnails show the open layout when the button drives it.
        let wide = simulate ? (simulatedWide ?? (isThumbnail || real == .regular)) : real == .regular
        MotionDemo(motion: state["motion"], simulate: simulate) {
            simulatedWide = !wide
        }
        .environment(\.horizontalSizeClass, simulate ? (wide ? .regular : .compact) : real)
    }
}

private struct MotionDemo: View {
    let motion: String
    let simulate: Bool
    let toggle: () -> Void
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isThumbnail) private var isThumbnail
    @Namespace private var space
    @State private var selection = 2
    @State private var listTop: Int?

    private var layout: MotionLayout { sizeClass == .regular ? .split : .stacked }
    /// The recommended option becomes a crossfade when Reduce Motion is on.
    private var style: String { motion == "mode" && reduceMotion ? "reduce" : motion }

    var body: some View {
        RegionReader { size, folds, _ in
            let geometry = Geometry(size: size, fold: folds.first, layout: layout)
            animated(stage(geometry), size: size)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    @ViewBuilder
    private func animated(_ content: some View, size: CGSize) -> some View {
        switch style {
        case "mode": content.animation(.smooth(duration: 0.35), value: layout)
        // Keyed on every size: the window's while it settles, and the panes' when the layout flips.
        case "everything": content.animation(.default, value: "\(size.width)x\(size.height)-\(layout)")
        case "reduce": content.animation(.easeInOut(duration: 0.25), value: layout)
        default: content.transaction { $0.animation = nil }
        }
    }

    @ViewBuilder
    private func stage(_ geometry: Geometry) -> some View {
        let screen = ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                header
                panes(geometry)
            }
            compose(geometry)
            if isThumbnail { MotionHint(style: style, geometry: geometry) }
        }
        if style == "reduce" {
            // Crossfade: the old layout fades out while the new one fades in; nothing slides.
            screen.id(layout).transition(.opacity)
        } else {
            screen
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Inbox").font(.title2.bold())
                Text(layout == .split ? "Two panes" : "One column")
                    .font(.caption).foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }
            Spacer()
            if simulate {
                Button(layout == .split ? "Show folded" : "Show open",
                       systemImage: layout == .split ? "iphone" : "rectangle.split.2x1", action: toggle)
                    .buttonStyle(.glassProminent)
            } else if motion == "mode" && reduceMotion {
                Label("Reduce Motion is on", systemImage: "figure.walk.motion")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func panes(_ geometry: Geometry) -> some View {
        let split = geometry.layout == .split
        let stack = split ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
        stack {
            list
                .frame(width: split ? geometry.listWidth : nil)
                .frame(maxHeight: split ? .infinity : geometry.size.height * 0.34)
            detail(columns: geometry.columns)
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(0..<30, id: \.self) { index in
                    Button { selection = index } label: {
                        HStack(spacing: 12) {
                            Tile(index: index, showsCaption: false).frame(width: 36, height: 36)
                            Text("\(Placeholder.name(index)) \(index + 1)").font(.body).lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(selection == index ? Color.accentColor.opacity(0.18) : .clear)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: $listTop, anchor: .top)
        .background(Color(.secondarySystemGroupedBackground))
    }

    @ViewBuilder
    private func detail(columns: Int) -> some View {
        let grid = LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns), spacing: 10) {
            ForEach(0..<24, id: \.self) { Tile(index: $0 + selection).aspectRatio(1, contentMode: .fit) }
        }
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(Placeholder.name(selection)) \(selection + 1)").font(.headline)
                if style == "everything" {
                    // Same cells, new places: each one animates to its new column.
                    grid
                } else {
                    // A new column count is a new grid: it fades in, the cells don't travel.
                    grid.id(columns).transition(.opacity)
                }
            }
            .padding(16)
        }
        // The last row can scroll clear of the compose button.
        .contentMargins(.bottom, 80, for: .scrollContent)
    }

    @ViewBuilder
    private func compose(_ geometry: Geometry) -> some View {
        let button = Image(systemName: "square.and.pencil")
            .font(.title2.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 60, height: 60)
            .background(Color.accentColor, in: .circle)
            .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
            .accessibilityLabel("Compose")
        // Two placements, one identity: the button travels between them when the layout flips.
        // Without movement (none, crossfade) each placement gets its own identity.
        let id = style == "mode" || style == "everything" ? "compose" : "compose-\(geometry.layout)"
        if geometry.layout == .stacked {
            button
                .matchedGeometryEffect(id: id, in: space)
                .position(geometry.composePoint(.stacked))
        } else {
            button
                .matchedGeometryEffect(id: id, in: space)
                .position(geometry.composePoint(.split))
        }
    }
}

private struct Geometry {
    let size: CGSize
    let fold: CGRect?
    let layout: MotionLayout

    /// In two panes the list fills the half before the fold, so nothing sits in the curve.
    var listWidth: CGFloat { fold?.minX ?? min(380, size.width * 0.4) }

    /// Even column counts, so a gap rather than a tile meets the fold.
    var columns: Int {
        let width = layout == .split ? size.width - listWidth : size.width
        let count = max(2, Int((width - 32 + 10) / (110 + 10)))
        return count % 2 == 0 ? count : count - 1
    }

    /// Folded: the bottom-trailing corner, where it sits over a tile's empty corner, not its
    /// caption. Open: the list pane's corner, clear of the fold.
    func composePoint(_ layout: MotionLayout) -> CGPoint {
        let y = size.height - 140
        switch layout {
        case .stacked: return CGPoint(x: size.width - 16 - 30, y: size.height - 16 - 30)
        case .split: return CGPoint(x: listWidth - 16 - 30, y: y)
        }
    }
}

/// Thumbnails are stills, so they sketch the motion each option produces.
private struct MotionHint: View {
    let style: String
    let geometry: Geometry

    var body: some View {
        let from = geometry.composePoint(geometry.layout == .split ? .stacked : .split)
        let to = geometry.composePoint(geometry.layout)
        ZStack {
            Circle()
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                .foregroundStyle(Color.accentColor.opacity(0.7))
                .frame(width: 60, height: 60)
                .position(from)
            switch style {
            case "mode":
                Path { path in
                    path.move(to: from)
                    path.addQuadCurve(to: to, control: CGPoint(x: (from.x + to.x) / 2, y: from.y - 80))
                }
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [8, 6]))
            case "everything":
                ForEach(0..<4, id: \.self) { index in
                    Tile(index: index)
                        .frame(width: 70, height: 70)
                        .opacity(0.35)
                        .rotationEffect(.degrees(Double(index) * 9 - 12))
                        .position(x: geometry.size.width * (0.45 + 0.12 * Double(index)), y: geometry.size.height * (0.35 + 0.1 * Double(index)))
                }
            default:
                EmptyView()
            }
        }
        .allowsHitTesting(false)
    }
}

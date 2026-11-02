import SwiftUI

/// An option running live and full screen, with a floating glass bar you can drag anywhere.
struct PreviewScreen: View {
    let lab: LabID
    @AppStorage(ReachOverlay.storageKey) private var showsReach = false
    let entrance: PreviewEntrance
    /// The option whose card was tapped; the zoom always returns to that card.
    let openedIndex: Int
    @State private var index: Int
    @State private var state: KnobState
    @State private var showsInfo = false
    /// False while arriving or leaving: the zoom shows the card's picture, the fade shows nothing.
    @State private var settled: Bool
    @State private var closing = false
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.horizontalSizeClass) private var sizeClass

    init(target: PreviewTarget) {
        lab = target.lab
        entrance = target.entrance
        let index = target.lab.options.firstIndex { $0.id == target.optionID } ?? 0
        _index = State(initialValue: index)
        openedIndex = index
        let state = KnobState(lab: target.lab, values: target.lab.options[index].knobs)
        state.apply(target.knobs)
        _state = State(initialValue: state)
        _settled = State(initialValue: target.entrance == .system)
    }

    private var option: LabOption { lab.options[index] }

    /// The card's picture of the current option on this display, if it has been rendered.
    private var cardImage: UIImage? {
        let pose: PreviewPose = sizeClass == .regular ? .open : .folded
        return ThumbnailRenderer.shared.images[
            ThumbnailRenderer.key(lab: lab, values: option.knobs, pose: pose, scheme: scheme)]
    }

    var body: some View {
        let fades = entrance == .fade
        // Every arrival/leave animation is scoped to opacity and scale only: an unscoped
        // withAnimation here would also animate the live view's first layout (tiles grow in).
        let speed = Animation.easeOut(duration: entrance == .zoom ? 0.2 : 0.24)
        ZStack {
            LabContent(lab: lab, state: state)
                .id(index)
            // Zoom: the first and last frames are the card's own picture, so the morph is seamless;
            // the live view (whose bars lay out a beat later) cross-fades in underneath.
            if entrance == .zoom, let image = cardImage {
                Image(uiImage: image)
                    .resizable()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .animation(speed) { $0.opacity(settled ? 0 : 1) }
            }
        }
        .background(Color(.systemBackground))
        .animation(speed) {
            $0.opacity(fades && !settled ? 0 : 1)
                .scaleEffect(fades && !settled ? 0.97 : 1)
        }
        .overlay {
            // Reach bands sit under the floating bar, so the bar stays readable.
            if showsReach { ReachOverlay() }
        }
        .overlay {
            // `-duolab.hideBar 1` hides the lab controls for clean captures.
            if !UserDefaults.standard.bool(forKey: "duolab.hideBar") {
            FloatingBar {
                OptionBarContent(lab: lab, option: option, index: index, state: state,
                                 onClose: close, onStep: step, onInfo: { showsInfo = true })
            }
            .animation(speed) { $0.opacity(settled ? 1 : 0) }
            }
        }
        .sheet(isPresented: $showsInfo) { OptionInfoSheet(lab: lab, option: option, state: state) }
        .duoChrome(includesReach: false)
        .task {
            guard !settled else { return }
            // Zoom: let the morph finish on the picture. Fade: wait one layout pass.
            try? await Task.sleep(for: .milliseconds(entrance == .zoom ? 380 : 30))
            settled = true
        }
    }

    private func step(_ delta: Int) {
        let count = lab.options.count
        withAnimation(.snappy) {
            index = (index + delta + count) % count
            state = KnobState(lab: lab, values: lab.options[index].knobs)
        }
    }

    /// The arrival played backwards: back to the picture (zoom) or out (fade), then go.
    private func close() {
        guard !closing else { return }
        closing = true
        switch entrance {
        case .system:
            dismiss()
        case .zoom:
            // Only swap to the card's picture when it shows what is on screen: same option, knobs
            // untouched. Otherwise the live view zooms back into the card the user came from.
            let matches = index == openedIndex
                && state.variantKey == KnobState(lab: lab, values: option.knobs).variantKey
            guard matches, cardImage != nil else { return dismiss() }
            settled = false
            Task {
                try? await Task.sleep(for: .milliseconds(200))
                dismiss()
            }
        case .fade:
            settled = false
            Task {
                try? await Task.sleep(for: .milliseconds(240))
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { router.preview = nil }
            }
        }
    }
}

/// Floats its content over the screen. Drag it and it snaps to the nearest of six spots
/// (top or bottom; leading, center or trailing), remembered across launches.
struct FloatingBar<Content: View>: View {
    @ViewBuilder let content: Content
    @AppStorage("duolab.barSpot") private var spot = 3
    @State private var drag: CGSize = .zero
    @State private var size: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            let base = point(spot, in: proxy.size)
            content
                .fixedSize()
                .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
                .position(x: base.x + drag.width, y: base.y + drag.height)
                .gesture(
                    DragGesture(minimumDistance: 6)
                        .onChanged { drag = $0.translation }
                        .onEnded { value in
                            let end = CGPoint(x: base.x + value.translation.width, y: base.y + value.translation.height)
                            let nearest = (0..<6).min { a, b in
                                distance(point(a, in: proxy.size), end) < distance(point(b, in: proxy.size), end)
                            } ?? spot
                            withAnimation(.snappy) {
                                spot = nearest
                                drag = .zero
                            }
                        }
                )
                .sensoryFeedback(.impact(weight: .light), trigger: spot)
        }
    }

    /// Spots 0–2 along the top, 3–5 along the bottom; leading, center, trailing.
    private func point(_ spot: Int, in container: CGSize) -> CGPoint {
        let margin: CGFloat = 14
        let half = CGSize(width: size.width / 2, height: size.height / 2)
        let xs = [margin + half.width, container.width / 2, container.width - margin - half.width]
        let ys = [margin + half.height, container.height - margin - half.height]
        return CGPoint(x: xs[spot % 3], y: ys[spot / 3])
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
}

/// Close · ‹ option › · info, in one glass capsule.
struct OptionBarContent: View {
    let lab: LabID
    let option: LabOption
    let index: Int
    let state: KnobState
    var onClose: () -> Void
    var onStep: (Int) -> Void
    var onInfo: () -> Void
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VStack(spacing: 8) {
            if let id = option.highlight, let spec = state.spec(id) {
                Picker(spec.title, selection: Binding(get: { state[id] }, set: { state[id] = $0 })) {
                    ForEach(spec.options, id: \.value) { Text($0.label).tag($0.value) }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
                .padding(5)
                .glassEffect(.regular, in: .capsule)
            }
            HStack(spacing: 2) {
                Button("Close", systemImage: "xmark", action: onClose)
                    .frame(width: 40, height: 44)
                Button("Previous", systemImage: "chevron.left") { onStep(-1) }
                    .frame(width: 34, height: 44)
                VStack(spacing: 1) {
                    Text(option.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text("\(option.verdict.title) · \(index + 1) of \(lab.options.count)")
                        .font(.caption2)
                        .foregroundStyle(option.verdict.color)
                }
                .frame(maxWidth: sizeClass == .regular ? 340 : 200)
                Button("Next", systemImage: "chevron.right") { onStep(1) }
                    .frame(width: 34, height: 44)
                Button("About this option", systemImage: "info.circle", action: onInfo)
                    .frame(width: 40, height: 44)
            }
            .labelStyle(.iconOnly)
            .font(.body.weight(.semibold))
            .padding(.horizontal, 6)
            .glassEffect(.regular.interactive(), in: .capsule)
            .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
        }
    }
}

/// What the option is, in plain words, with the technical bits at the bottom.
struct OptionInfoSheet: View {
    let lab: LabID
    let option: LabOption
    let state: KnobState
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var router = router
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(option.verdict.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(option.verdict.color)
                        Text(option.title).font(.title2.bold())
                        Text(option.summary).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                Section("Try this") {
                    Text(option.lookFor)
                }
                if !option.pros.isEmpty {
                    Section("Good") {
                        ForEach(option.pros, id: \.self) { Label($0, systemImage: "hand.thumbsup").labelStyle(SoftLabel(color: .green)) }
                    }
                }
                if !option.cons.isEmpty {
                    Section("Watch out") {
                        ForEach(option.cons, id: \.self) { Label($0, systemImage: "exclamationmark.circle").labelStyle(SoftLabel(color: .orange)) }
                    }
                }
                Section("Apple suggests") {
                    Text(lab.guidance)
                }
                Section {
                    if let note = option.buildNote(in: lab) {
                        Text(note).font(.footnote.monospaced()).foregroundStyle(.secondary)
                    }
                    NavigationLink("Adjust settings") { FineTuneView(state: state, option: option) }
                    Toggle("Show measurements", isOn: $router.measure)
                } header: {
                    Text("How it’s built")
                }
            }
            .navigationTitle(lab.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Color(.systemGroupedBackground))
    }
}

private struct SoftLabel: LabelStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            configuration.icon.foregroundStyle(color)
            configuration.title
        }
    }
}

/// Raw settings behind an option.
struct FineTuneView: View {
    @Bindable var state: KnobState
    let option: LabOption

    var body: some View {
        Form {
            KnobSections(state: state)
            Section {
                Button("Reset to “\(option.title)”", systemImage: "arrow.counterclockwise") {
                    state.reset()
                    state.apply(option.knobs)
                }
            }
        }
        .navigationTitle("Fine-tune")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// One picker per knob, with Apple's note as the footer.
struct KnobSections: View {
    @Bindable var state: KnobState

    var body: some View {
        ForEach(state.specs) { spec in
            Section {
                Picker(spec.title, selection: Binding(get: { state[spec.id] }, set: { state[spec.id] = $0 })) {
                    ForEach(spec.options, id: \.value) { Text($0.label).tag($0.value) }
                }
                .pickerStyle(.menu)
            } footer: {
                Text(spec.note)
            }
        }
    }
}

/// Routes a lab id to its demo view.
struct LabContent: View {
    let lab: LabID
    let state: KnobState

    var body: some View {
        switch lab {
        case .tabBar: TabBarLabView(state: state)
        case .toolbars: ToolbarsLabView(state: state)
        case .listDetail: ListDetailLabView(state: state)
        case .grids: GridsLabView(state: state)
        case .reading: ReadingLabView(state: state)
        case .media: MediaLabView(state: state)
        case .overlays: OverlaysLabView(state: state)
        case .sheets: SheetsLabView(state: state)
        case .hinge: HingeLabView(state: state)
        case .antiPatterns: AntiPatternsLabView(state: state)
        case .continuity: ContinuityLabView(state: state)
        case .laptopPose: LaptopPoseLabView(state: state)
        case .motion: MotionLabView(state: state)
        case .toasts: ToastsLabView(state: state)
        case .twoPanes: TwoPanesLabView(state: state)
        case .keyboard: KeyboardLabView(state: state)
        case .transitions: TransitionsLabView(state: state)
        }
    }
}

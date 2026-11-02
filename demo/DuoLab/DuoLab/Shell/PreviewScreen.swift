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
    /// A fade's way out is always a whole-screen fade, even when it arrived on a picture.
    @State private var leaving = false
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
        // The picture of this option on this display, when the card (or the tap) had one ready.
        // Zoom always has it; a fade has it when the tap pre-rendered it in time.
        let picture = entrance == .system ? nil : cardImage
        // Without a picture, a fade brings the whole screen in from nothing.
        let fades = entrance == .fade && (picture == nil || leaving)
        // Every arrival/leave animation is scoped to opacity and scale only: an unscoped
        // withAnimation here would also animate the live view's first layout (tiles grow in).
        let speed = Animation.easeOut(duration: entrance == .zoom ? 0.2 : 0.24)
        ZStack {
            LabContent(lab: lab, state: state)
                .id(index)
            // The first frame is the picture, so there is no frame of the live view laid out at the
            // wrong width; the live view (whose bars lay out a beat later) cross-fades in underneath.
            if let picture, !leaving || entrance == .zoom {
                Image(uiImage: picture)
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
                FloatingBar(compactTop: lab.barCompactTop) { touched in
                    OptionBarContent(lab: lab, option: option, index: index, state: state, onTouch: touched,
                                     onClose: close, onStep: step, onInfo: { showsInfo = true })
                } handle: {
                    BarHandle(lab: lab, option: option, index: index)
                }
                .animation(speed) { $0.opacity(settled ? 1 : 0) }
            }
        }
        .sheet(isPresented: $showsInfo) { OptionInfoSheet(lab: lab, option: option, state: state) }
        .duoChrome(includesReach: false)
        .task {
            // Hold the background thumbnail work while this screen arrives: each render shows a
            // hidden window and forces a screen update, which slows the arrival down.
            ThumbnailRenderer.shared.hold(for: .seconds(1))
            guard !settled else { return }
            // With a picture, let the live view lay out under it before cross-fading.
            // A fade without one waits a single layout pass.
            try? await Task.sleep(for: .milliseconds(cardImage != nil ? 380 : 30))
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
            leaving = true
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

/// Floats the lab controls over the screen. Expanded, they sit at one of six spots (top or
/// bottom; leading, center or trailing); drag them and they snap to the nearest, remembered per
/// display across launches. After a few seconds without a touch they fold into a slim handle on
/// the trailing content edge, vertically centred, where demos put no controls; tap it to expand.
///
/// Default spot is top-trailing (just left of the rail). On the outer display the top row sits a
/// title-line lower, under a large navigation title instead of on it. While the keyboard is up a
/// bottom spot moves to the top of the same column, so the bar never sits on or near the keys.
struct FloatingBar<Content: View, Handle: View>: View {
    /// How far below the top the top row starts on the outer display.
    var compactTop: CGFloat = 50
    /// The expanded controls. Call the closure on every touch: it restarts the idle timer.
    @ViewBuilder let content: (_ touched: @escaping () -> Void) -> Content
    @ViewBuilder let handle: Handle
    /// Seconds without a touch before the bar folds into its handle.
    static var idleDelay: Duration { .seconds(3) }
    @AppStorage("duolab.barSpot.compact") private var compactSpot = 2
    @AppStorage("duolab.barSpot.regular") private var regularSpot = 2
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var drag: CGSize = .zero
    @State private var size: CGSize = .zero
    @State private var keyboardUp = false
    @State private var collapsed = false
    /// Bumped by every touch on the bar; restarts the idle timer.
    @State private var activity = 0

    private var spot: Int {
        get { sizeClass == .regular ? regularSpot : compactSpot }
        nonmutating set { if sizeClass == .regular { regularSpot = newValue } else { compactSpot = newValue } }
    }

    /// The spot actually used: a bottom spot lifts to the top while the keyboard is up.
    private var shown: Int { keyboardUp ? spot % 3 : spot }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if collapsed {
                    Button(action: touched) { handle }
                        .buttonStyle(.plain)
                        .position(x: proxy.size.width - BarHandle.hitSize.width / 2 - 1,
                                  y: proxy.size.height / 2)
                        .transition(.scale(scale: 0.5, anchor: .trailing).combined(with: .opacity))
                } else {
                    let base = point(shown, in: proxy.size)
                    content(touched)
                        .fixedSize()
                        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
                        .position(x: base.x + drag.width, y: base.y + drag.height)
                        .gesture(
                            DragGesture(minimumDistance: 6)
                                .onChanged { drag = $0.translation; activity += 1 }
                                .onEnded { value in
                                    let end = CGPoint(x: base.x + value.translation.width, y: base.y + value.translation.height)
                                    let nearest = (0..<6).min { a, b in
                                        distance(point(a, in: proxy.size), end) < distance(point(b, in: proxy.size), end)
                                    } ?? spot
                                    withAnimation(.snappy) {
                                        spot = nearest
                                        drag = .zero
                                    }
                                    touched()
                                }
                        )
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .sensoryFeedback(.impact(weight: .light), trigger: spot)
            .animation(.snappy, value: shown)
            .animation(.snappy, value: collapsed)
        }
        // The keyboard is handled above (top row), so its safe area must not push the bar around.
        .ignoresSafeArea(.keyboard)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardUp = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardUp = false }
        .task(id: activity) {
            try? await Task.sleep(for: Self.idleDelay)
            guard !Task.isCancelled else { return }
            collapsed = true
        }
    }

    private func touched() {
        collapsed = false
        activity += 1
    }

    /// Spots 0–2 along the top, 3–5 along the bottom; leading, center, trailing.
    private func point(_ spot: Int, in container: CGSize) -> CGPoint {
        let margin: CGFloat = 14
        // Folded, most demos open on a large title at the top: the top row sits under it.
        let top = margin + (sizeClass == .regular ? 0 : compactTop)
        let half = CGSize(width: size.width / 2, height: size.height / 2)
        let xs = [margin + half.width, container.width / 2, container.width - margin - half.width]
        let ys = [top + half.height, container.height - margin - half.height]
        return CGPoint(x: xs[spot % 3], y: ys[spot / 3])
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
}

extension LabID {
    /// Where the bar's top row starts on the outer display: under the large title, or under a
    /// demo's own readout pinned to the top (the bar moves, never the demo).
    var barCompactTop: CGFloat {
        switch self {
        case .keyboard: 118 // the keyboard readout card, y 10–122
        default: 50
        }
    }
}

/// The folded bar: a slim glass tab on the trailing edge with the verdict dot and a grabber.
/// 22 × 64 pt to look at; the tap target is 44 pt wide.
struct BarHandle: View {
    let lab: LabID
    let option: LabOption
    let index: Int
    static let hitSize = CGSize(width: 44, height: 64)

    var body: some View {
        VStack(spacing: 7) {
            Circle()
                .fill(option.verdict.color)
                .frame(width: 8, height: 8)
            Capsule()
                .fill(.secondary)
                .frame(width: 3, height: 22)
        }
        .frame(width: 22, height: 64)
        .glassEffect(.regular.interactive(), in: .capsule)
        .shadow(color: .black.opacity(0.12), radius: 6, y: 1)
        .frame(width: Self.hitSize.width, height: Self.hitSize.height, alignment: .trailing)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(option.title), \(option.verdict.title), \(index + 1) of \(lab.options.count)")
        .accessibilityHint("Shows the lab controls")
        .accessibilityAddTraits(.isButton)
    }
}

/// Close · ‹ option › · info, in one glass capsule, with the option's key setting above it.
struct OptionBarContent: View {
    let lab: LabID
    let option: LabOption
    let index: Int
    let state: KnobState
    /// Restarts the bar's idle timer.
    var onTouch: () -> Void
    var onClose: () -> Void
    var onStep: (Int) -> Void
    var onInfo: () -> Void
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var titleWidth: CGFloat { sizeClass == .regular ? 340 : 200 }

    var body: some View {
        VStack(spacing: 8) {
            if let id = option.highlight, let spec = state.spec(id) {
                HighlightPicker(spec: spec, state: state, maxWidth: sizeClass == .regular ? 460 : 300,
                                onChange: onTouch)
            }
            HStack(spacing: 2) {
                barButton("Close", "xmark", width: 40, action: onClose)
                barButton("Previous", "chevron.left", width: 34) { onTouch(); onStep(-1) }
                VStack(spacing: 1) {
                    // One line when it fits; otherwise two lines a size smaller, never cut off.
                    ViewThatFits(in: .horizontal) {
                        Text(option.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(option.title)
                            .font(.footnote.weight(.semibold))
                            .lineLimit(2)
                            .minimumScaleFactor(0.9)
                    }
                    .multilineTextAlignment(.center)
                    Text("\(option.verdict.title) · \(index + 1) of \(lab.options.count)")
                        .font(.caption2)
                        .foregroundStyle(option.verdict.color)
                }
                .frame(maxWidth: titleWidth)
                .fixedSize(horizontal: false, vertical: true)
                barButton("Next", "chevron.right", width: 34) { onTouch(); onStep(1) }
                barButton("About this option", "info.circle", width: 40) { onTouch(); onInfo() }
            }
            .font(.body.weight(.semibold))
            .padding(.horizontal, 6)
            .glassEffect(.regular.interactive(), in: .capsule)
            .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
        }
    }

    /// The whole 44 pt cell is the hit target, not just the glyph.
    private func barButton(_ title: String, _ symbol: String, width: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: width, height: 44)
                .contentShape(.rect)
        }
        .accessibilityLabel(title)
    }
}

/// The option's highlighted knob. Segmented when its choices fit; otherwise a menu that shows the
/// current value (more than three choices, or labels too long to read in a segment).
private struct HighlightPicker: View {
    let spec: KnobSpec
    let state: KnobState
    let maxWidth: CGFloat
    var onChange: () -> Void

    private var selection: Binding<String> {
        Binding(get: { state[spec.id] }, set: { state[spec.id] = $0; onChange() })
    }

    /// Segment widths measured with the segmented control's font plus its padding per segment.
    private var segmentsFit: Bool {
        guard spec.options.count <= 3 else { return false }
        let font = UIFont.systemFont(ofSize: 13, weight: .medium)
        let widest = spec.options.map { ($0.label as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
        return (widest + 28) * CGFloat(spec.options.count) <= maxWidth
    }

    var body: some View {
        if segmentsFit {
            Picker(spec.title, selection: selection) {
                ForEach(spec.options, id: \.value) { Text($0.label).tag($0.value) }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .padding(5)
            .glassEffect(.regular, in: .capsule)
        } else {
            Menu {
                Picker(spec.title, selection: selection) {
                    ForEach(spec.options, id: \.value) { Text($0.label).tag($0.value) }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(spec.title + ":").foregroundStyle(.secondary)
                    Text(spec.options.first { $0.value == state[spec.id] }?.label ?? state[spec.id])
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down").font(.caption2.weight(.bold))
                }
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: maxWidth)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .capsule)
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
            // Our own opaque header under the grabber: at the large detent the list would otherwise
            // scroll under the grabber, and the system bar put Done in the rail with no title.
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack(alignment: .center) {
                    Text(lab.title).font(.headline)
                    Spacer()
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .buttonStyle(.glassProminent)
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 10)
                .background(Color(.systemGroupedBackground))
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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
        case .camera: CameraLabView(state: state)
        case .narrowWindows: NarrowWindowsLabView(state: state)
        }
    }
}

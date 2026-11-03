import SwiftUI

/// The guided tour: every topic's recommended answer running live, one after another, with a
/// caption at the top and a glass strip at the bottom. Advances on its own every few seconds;
/// any touch holds it, and it picks up again once the screen is left alone.
struct TourScreen: View {
    @State private var model: TourModel
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("duolab.tourSeen") private var tourSeen = false
    /// The caption's height, so the live view starts below it instead of under it.
    @State private var captionHeight: CGFloat = 0
    /// The keyboard's top edge in window points while it is up (a step's lab can raise it).
    @State private var keyboardTop: CGFloat?
    /// Folded, the step during which the keyboard came up: compare turns into a single pane for
    /// the rest of that step (two stacked frames have no room left above the keys, and switching
    /// back would raise the keyboard again from the new frame).
    @State private var keyboardStep: String?
    @Environment(\.horizontalSizeClass) private var sizeClass

    init(launch: TourLaunch) {
        _model = State(initialValue: TourModel(launch: launch))
    }

    /// Compare shows two answers only when the topic has one to avoid, and folded only while the
    /// keyboard stays down.
    private var comparing: Bool { model.compare && model.step.avoid != nil && !compareHeldByKeyboard }

    private var compareHeldByKeyboard: Bool { sizeClass != .regular && keyboardStep == model.step.id }

    var body: some View {
        let step = model.step
        let keyboardLift = keyboardOverlap
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            if !comparing {
                // Clear of the caption and the strip, so nothing of the answer hides under them.
                // Added in UIKit, so the lab's own bars and lists see it too.
                InsetHost(content: TourLive(lab: step.lab, option: step.option).environment(router),
                          extra: UIEdgeInsets(top: captionHeight + 20, left: 0,
                                              bottom: (UserDefaults.standard.bool(forKey: "duolab.hideTourStrip") ? 0 : 64) + keyboardLift,
                                              right: 0))
                    .ignoresSafeArea()
                    .id("single-\(step.id)")
                    .transition(.opacity)
            }
            EnvironmentProbe { snapshot in
                TourOverlay(model: model, layout: TourLayout(snapshot), comparing: comparing,
                            keyboardTop: keyboardTop, compareHeld: model.compare && compareHeldByKeyboard,
                            reduceMotion: reduceMotion, onStep: go, onClose: { router.closeTour() },
                            onOpen: open, onCaptionHeight: { captionHeight = $0 })
            }
            .ignoresSafeArea(.keyboard)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            keyboardChanged(frame)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.snappy) { keyboardTop = nil }
        }
        .gesture(TouchWatcher { model.touched() })
        .duoChrome()
        .onAppear { tourSeen = true }
        .task(id: reduceMotion) {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                if model.tick(0.1, reduceMotion: reduceMotion) { go(1) }
            }
        }
    }

    /// How far the keyboard reaches up from the window's bottom edge (0 while it is down).
    private var keyboardOverlap: CGFloat {
        guard let keyboardTop, let window = keyWindowHeight else { return 0 }
        return max(0, window - keyboardTop)
    }

    private var keyWindowHeight: CGFloat? {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.keyWindow?.bounds.height
    }

    private func keyboardChanged(_ screenFrame: CGRect) {
        // Keyboard frames are in screen coordinates; the app's window fills its screen.
        let height = keyWindowHeight ?? screenFrame.maxY
        let up = screenFrame.height > 0 && screenFrame.minY < height - 1
        withAnimation(.snappy) {
            keyboardTop = up ? screenFrame.minY : nil
            if up, sizeClass != .regular { keyboardStep = model.step.id }
        }
    }

    /// A short crossfade for the live view; the caption slides (see `TourOverlay`).
    private func go(_ delta: Int) {
        withAnimation(.easeInOut(duration: reduceMotion ? 0.2 : 0.4)) { model.go(delta) }
    }

    private func open() {
        let step = model.step
        router.closeTour(opening: PreviewTarget(lab: step.lab, optionID: step.option.id, entrance: .fade))
    }
}

/// Where things go, in window points: the safe area, and the fold (the real one in book pose, the
/// middle of the window when open flat) so nothing the tour draws sits on it or under the rail.
struct TourLayout {
    let safe: CGRect
    let fold: CGRect?

    init(_ snapshot: EnvironmentSnapshot) {
        let size = snapshot.size
        let insets = snapshot.safeArea
        safe = CGRect(x: insets.leading, y: insets.top,
                      width: max(size.width - insets.leading - insets.trailing, 0),
                      height: max(size.height - insets.top - insets.bottom, 0))
        if let real = snapshot.fold, real.height > real.width {
            fold = real
        } else if snapshot.horizontal == .regular {
            fold = CGRect(x: size.width / 2 - 14, y: 0, width: 28, height: size.height)
        } else {
            fold = nil
        }
    }

    /// The pane the caption and the strip live in: leading of the fold, or the whole safe area.
    var leading: CGRect {
        guard let fold else { return safe }
        return CGRect(x: safe.minX, y: safe.minY, width: max(fold.minX - safe.minX, 0), height: safe.height)
    }

    var trailing: CGRect? {
        guard let fold else { return nil }
        return CGRect(x: fold.maxX, y: safe.minY, width: max(safe.maxX - fold.maxX, 0), height: safe.height)
    }
}

/// Caption, compare stage and strip, laid out in window coordinates.
private struct TourOverlay: View {
    let model: TourModel
    let layout: TourLayout
    let comparing: Bool
    /// The keyboard's top edge in window points, while it is up: the strip sits above it.
    var keyboardTop: CGFloat?
    /// Compare is on, but shows a single pane because the keyboard is up (folded).
    var compareHeld = false
    let reduceMotion: Bool
    var onStep: (Int) -> Void
    var onClose: () -> Void
    var onOpen: () -> Void
    var onCaptionHeight: (CGFloat) -> Void

    private let margin: CGFloat = 16
    /// Room kept free at the bottom for the strip while comparing.
    private let stripRoom: CGFloat = 80

    /// Captures only: `-duolab.hideTourStrip 1`. Not tied to the lab bar's capture flag, so a
    /// leftover `-duolab.hideBar` can never leave someone in a tour without controls.
    private var hidesStrip: Bool { UserDefaults.standard.bool(forKey: "duolab.hideTourStrip") }

    private var slide: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(insertion: .offset(x: model.forward ? 28 : -28).combined(with: .opacity),
                           removal: .opacity)
    }

    var body: some View {
        let step = model.step
        ZStack(alignment: .topLeading) {
            Color.clear
            if comparing, let avoid = step.avoid {
                Group {
                    if let trailing = layout.trailing, let fold = layout.fold {
                        sideBySide(step, avoid: avoid, trailing: trailing, fold: fold)
                    } else {
                        stacked(step, avoid: avoid)
                    }
                }
                .id("compare-\(step.id)")
                .transition(.opacity)
            } else {
                let pane = layout.leading
                TourCaption(step: step, option: step.option, compareNote: model.compare, keyboardNote: compareHeld)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: min(pane.width - 2 * margin, 460))
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onCaptionHeight($0) }
                    .id("caption-\(step.id)")
                    .transition(slide)
                    .contentShape(.rect)
                    // Swipe the caption card to change step: left for next, right for back.
                    .gesture(DragGesture(minimumDistance: 24).onEnded { value in
                        let dx = value.translation.width
                        guard abs(dx) > 50, abs(dx) > abs(value.translation.height) else { return }
                        onStep(dx < 0 ? 1 : -1)
                    })
                    .accessibilityAction(named: "Next topic") { onStep(1) }
                    .accessibilityAction(named: "Previous topic") { onStep(-1) }
                    .offset(x: pane.minX + margin, y: pane.minY + 12)
            }
            if !hidesStrip {
                let pane = layout.leading
                // Above the keyboard when it covers the pane's bottom edge.
                let lift = keyboardTop.map { max(0, pane.maxY - $0) } ?? 0
                TourStrip(model: model, reduceMotion: reduceMotion, onStep: onStep,
                          onClose: onClose, onOpen: onOpen)
                    .frame(width: pane.width, height: max(pane.height - 14 - lift, 60), alignment: .bottom)
                    .offset(x: pane.minX, y: pane.minY)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Open: Recommended in the leading pane, Avoid in the trailing one, split on the fold.
    private func sideBySide(_ step: TourStep, avoid: LabOption, trailing: CGRect, fold: CGRect) -> some View {
        let leading = layout.leading
        let gap: CGFloat = 12
        let leadingWidth = max(leading.width - margin - gap, 0)
        let trailingWidth = max(trailing.width - gap - margin, 0)
        let between = gap + fold.width + gap
        return VStack(alignment: .leading, spacing: 12) {
            // Same height on both sides, so the two pictures start on one line.
            HStack(alignment: .top, spacing: between) {
                TourCaption(step: step, option: step.option, compareNote: false)
                    .frame(width: leadingWidth)
                    .frame(maxHeight: .infinity, alignment: .top)
                TourCaption(step: step, option: avoid, compareNote: false)
                    .frame(width: trailingWidth)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: between) {
                TourFrame(lab: step.lab, option: step.option, forceCompact: true)
                    .frame(width: leadingWidth)
                TourFrame(lab: step.lab, option: avoid, forceCompact: true)
                    .frame(width: trailingWidth)
            }
        }
        .padding(.leading, margin)
        .padding(.top, 12)
        .padding(.bottom, stripRoom)
        .frame(width: layout.safe.width, height: layout.safe.height, alignment: .topLeading)
        .offset(x: layout.safe.minX, y: layout.safe.minY)
    }

    /// Folded: one caption, Recommended on top, Avoid below.
    private func stacked(_ step: TourStep, avoid: LabOption) -> some View {
        VStack(spacing: 10) {
            TourCaption(step: step, option: step.option, compareNote: false, avoid: avoid)
                .fixedSize(horizontal: false, vertical: true)
            TourFrame(lab: step.lab, option: step.option, forceCompact: false)
            TourFrame(lab: step.lab, option: avoid, forceCompact: false)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, stripRoom)
        .frame(width: layout.safe.width, height: layout.safe.height)
        .offset(x: layout.safe.minX, y: layout.safe.minY)
    }
}

/// Topic, question, verdict and one line of why.
private struct TourCaption: View {
    let step: TourStep
    let option: LabOption
    /// Compare is on but this topic has nothing to avoid.
    var compareNote: Bool
    /// Folded compare: one caption names both answers.
    var avoid: LabOption?
    /// Folded compare is held to one pane while the keyboard is up.
    var keyboardNote = false

    private var isAvoid: Bool { option.verdict == .avoid }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(step.lab.title).font(.headline)
                Spacer(minLength: 4)
                VerdictChip(verdict: option.verdict, compact: true)
            }
            if !isAvoid {
                Text(step.lab.question)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(option.title).font(.subheadline.weight(.semibold))
            (Text(isAvoid ? "Why not: " : "Why: ").fontWeight(.semibold) + Text(option.summary))
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            if let avoid {
                (Text("Below, to avoid: ").fontWeight(.semibold) + Text(avoid.title))
                    .font(.footnote)
                    .foregroundStyle(Verdict.avoid.color)
            }
            if keyboardNote {
                Text("Keyboard up: showing only the answer to use.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if compareNote, step.avoid == nil {
                Text("Nothing to avoid in this topic, so there is no comparison.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        // Glass alone turns muddy grey over dark video (Media, Laptop, Camera): a thin material
        // under it keeps the text on a light (or, in dark mode, dark) ground everywhere.
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .shadow(color: .black.opacity(0.16), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
    }
}

/// One answer, running live inside a rounded frame with its verdict on the corner.
private struct TourFrame: View {
    let lab: LabID
    let option: LabOption
    /// Half of the inner display is a phone-width window; tell the lab so.
    let forceCompact: Bool
    @Environment(AppRouter.self) private var router

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        // The frame already sits inside the safe area, so the host gives the lab no insets.
        // (A navigation stack still keeps its own trailing column for side bars; that is the
        // system's behavior in any window this narrow, so it is left as is.)
        InsetFreeHost(content: TourLive(lab: lab, option: option).environment(router), compact: forceCompact)
            .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .clipShape(shape)
        .overlay(shape.strokeBorder(option.verdict.color.opacity(0.55), lineWidth: 1.5))
        .overlay(alignment: .topTrailing) {
            Label(option.verdict.title, systemImage: option.verdict.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(option.verdict.color, in: .capsule)
                .padding(8)
                .accessibilityHidden(true)
        }
    }
}

/// An option running live, with its own knob state.
private struct TourLive: View {
    let lab: LabID
    @State private var state: KnobState

    init(lab: LabID, option: LabOption) {
        self.lab = lab
        _state = State(initialValue: KnobState(lab: lab, values: option.knobs))
    }

    var body: some View {
        LabContent(lab: lab, state: state)
    }
}

/// Hosts a live lab inside a frame: no safe-area insets (the frame is already clear of the rail),
/// and, on half of the inner display, a compact width trait the way a phone-width window gets it.
/// The environment value alone does not reach the system bars and split views inside a lab.
private struct InsetFreeHost<Content: View>: UIViewControllerRepresentable {
    let content: Content
    let compact: Bool

    func makeUIViewController(context: Context) -> UIHostingController<Content> {
        let host = UIHostingController(rootView: content)
        host.safeAreaRegions = []
        host.view.backgroundColor = .systemBackground
        if compact { host.traitOverrides.horizontalSizeClass = .compact }
        return host
    }

    func updateUIViewController(_ host: UIHostingController<Content>, context: Context) {
        host.rootView = content
    }
}

/// Hosts the full-screen live lab with extra safe area at the top and bottom. A SwiftUI
/// safe-area padding stops at the lab's navigation stack; UIKit's additional insets do not.
private struct InsetHost<Content: View>: UIViewControllerRepresentable {
    let content: Content
    let extra: UIEdgeInsets

    func makeUIViewController(context: Context) -> UIHostingController<Content> {
        let host = UIHostingController(rootView: content)
        host.view.backgroundColor = .systemBackground
        host.additionalSafeAreaInsets = extra
        return host
    }

    func updateUIViewController(_ host: UIHostingController<Content>, context: Context) {
        host.rootView = content
        if host.additionalSafeAreaInsets != extra { host.additionalSafeAreaInsets = extra }
    }
}

/// Close · pause · ‹ n/N › · compare · open, in one glass capsule with the step's progress.
private struct TourStrip: View {
    let model: TourModel
    let reduceMotion: Bool
    var onStep: (Int) -> Void
    var onClose: () -> Void
    var onOpen: () -> Void
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        HStack(spacing: 2) {
            button("Close tour", "xmark", width: 40, action: onClose)
            if !reduceMotion {
                button(model.userPaused ? "Play" : "Pause",
                       model.userPaused ? "play.fill" : "pause.fill", width: 38) { model.togglePlay() }
            }
            button("Previous topic", "chevron.left", width: 32) { onStep(-1) }
                .disabled(model.isFirst)
            Text("\(model.index + 1)/\(model.steps.count)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .frame(minWidth: 44)
                .accessibilityLabel("Topic \(model.index + 1) of \(model.steps.count)")
            button("Next topic", "chevron.right", width: 32) { onStep(1) }
                .disabled(model.isLast)
            compareButton
            openButton
        }
        .font(.body.weight(.semibold))
        .padding(.horizontal, 6)
        .padding(.bottom, reduceMotion ? 0 : 3)
        .overlay(alignment: .bottom) {
            if !reduceMotion { progress }
        }
        .background(.ultraThinMaterial, in: .capsule)
        .glassEffect(.regular.interactive(), in: .capsule)
        .shadow(color: .black.opacity(0.16), radius: 12, y: 4)
        .fixedSize()
    }

    private var progress: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(.tint)
                .frame(width: proxy.size.width * model.progress)
                .animation(model.elapsed == 0 ? nil : .linear(duration: 0.1), value: model.elapsed)
        }
        .frame(height: 3)
        .background(.secondary.opacity(0.2), in: .capsule)
        .padding(.horizontal, 24)
        .padding(.bottom, 5)
        .accessibilityHidden(true)
    }

    private var compareButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) { model.compare.toggle() }
        } label: {
            Image(systemName: model.compare ? "rectangle.split.2x1.fill" : "rectangle.split.2x1")
                .foregroundStyle(model.compare ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                .frame(width: 40, height: 44)
                .contentShape(.rect)
        }
        .accessibilityLabel("Compare with the answer to avoid")
        .accessibilityAddTraits(model.compare ? .isSelected : [])
    }

    private var openButton: some View {
        Button(action: onOpen) {
            Text(sizeClass == .regular ? "Open this topic" : "Go to topic")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(.tint.opacity(0.15), in: .capsule)
                .padding(.leading, 4)
                .padding(.trailing, 2)
                .frame(height: 44)
                .contentShape(.rect)
        }
        .accessibilityLabel("Open this topic")
    }

    /// The whole 44 pt cell is the hit target, not just the glyph.
    private func button(_ title: String, _ symbol: String, width: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: width, height: 44)
                .contentShape(.rect)
        }
        .accessibilityLabel(title)
    }
}

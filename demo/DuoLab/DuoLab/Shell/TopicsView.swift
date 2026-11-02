import SwiftUI

/// Main page: the topics. Folded, a list that pushes each topic. Open, a split view: the list in
/// the leading column, the chosen topic's options in the trailing one, the divider on the fold.
struct TopicsView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Namespace private var zoom
    /// Both columns stay up open, even with a topic chosen: the pattern is the point.
    @State private var columns = NavigationSplitViewVisibility.all
    @AppStorage("duolab.tourSeen") private var tourSeen = false

    private var labs: [LabID] { LabID.catalog }

    var body: some View {
        Group {
            if sizeClass == .regular { split } else { stack }
        }
        .fullScreenCover(item: coverTarget) { target in
            // Keyed on the target: a link that swaps the option without a transition (see
            // `AppRouter.handle`) keeps the cover up, and must still get a fresh screen.
            switch target.entrance {
            case .zoom:
                PreviewScreen(target: target).id(target)
                    .navigationTransition(.zoom(sourceID: target.id, in: zoom))
            case .fade:
                PreviewScreen(target: target).id(target)
                    .presentationBackground(.clear)
            case .system, .linked:
                PreviewScreen(target: target).id(target)
            }
        }
    }

    /// The option shown in the cover. A linked option is drawn by the root view instead (see
    /// `PreviewEntrance.linked`), and the cover going away for it must not clear it.
    private var coverTarget: Binding<PreviewTarget?> {
        Binding(get: { router.preview?.entrance.usesCover == true ? router.preview : nil },
                set: { if $0 != nil || router.preview?.entrance.usesCover == true { router.preview = $0 } })
    }

    private var stack: some View {
        @Bindable var router = router
        return NavigationStack(path: $router.path) {
            List {
                tourEntry
                intro
                Section {
                    ForEach(labs) { lab in
                        NavigationLink(value: lab) { TopicRow(lab: lab) }
                    }
                }
            }
            .navigationTitle("iPhone Duo")
            .navigationDestination(for: LabID.self) { TopicView(lab: $0, zoom: zoom) }
        }
    }

    /// `router.path` stays the source of truth, so `-topic` links land on the same topic folded or open.
    private var selection: Binding<LabID?> {
        Binding(get: { router.path.last }, set: { router.path = $0.map { [$0] } ?? [] })
    }

    private var split: some View {
        GeometryReader { proxy in
            // The whole window, rail included: its middle is where the fold is.
            let window = proxy.size.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing
            NavigationSplitView(columnVisibility: $columns) {
                List(selection: selection) {
                    tourEntry
                    intro
                    Section {
                        ForEach(labs) { lab in
                            NavigationLink(value: lab) { TopicRow(lab: lab) }
                        }
                    }
                }
                .navigationTitle("iPhone Duo")
                // Half the window: the column divider lands on the fold in book pose.
                .navigationSplitViewColumnWidth(min: 280, ideal: window / 2, max: window / 2)
            } detail: {
                NavigationStack {
                    if let lab = router.path.last {
                        TopicView(lab: lab, zoom: zoom).id(lab)
                    } else {
                        ContentUnavailableView("Pick a topic", systemImage: "list.bullet.rectangle",
                                               description: Text("Its possible answers show here."))
                    }
                }
            }
            .navigationSplitViewStyle(.balanced)
        }
    }

    /// First launch: a one-time card. After that, a plain button at the top of the list.
    private var tourEntry: some View {
        Section {
            if tourSeen {
                Button { router.startTour() } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Start the tour").font(.headline)
                            Text("Every topic\u{2019}s best answer, one after another. About \(TourStep.minutes) minutes.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "play.circle.fill").font(.title2).foregroundStyle(.tint)
                    }
                }
                .buttonStyle(.plain)
            } else {
                TourInvite(onStart: { router.startTour() }, onDismiss: { withAnimation { tourSeen = true } })
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 12))
            }
        }
    }

    private var intro: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(labs.count) layout questions for a foldable. Open one to see the possible answers, then try each answer full screen.")
                Text("Drag the floating bar out of the way; switch Open / Folded to see each answer on either display.")
                    .font(.footnote)
            }
            .foregroundStyle(.secondary)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
        }
    }
}

/// "New here?" One time, at the top of the list; never in the way of the topics below it.
private struct TourInvite: View {
    var onStart: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "play.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 8) {
                Text("New here? Take the \(TourStep.minutes)\u{2011}minute tour.").font(.headline)
                Text("It plays each topic\u{2019}s best answer, live, with a line on why. Touch the screen to hold it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Start the tour", systemImage: "play.fill", action: onStart)
                    .buttonStyle(.glassProminent)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
            Button("Not now", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .contentShape(.rect)
                .buttonStyle(.plain)
        }
    }
}

private struct TopicRow: View {
    let lab: LabID

    var body: some View {
        HStack(spacing: 14) {
            OptionThumbnail(lab: lab, option: lab.featuredOption, pose: .open)
                .frame(width: 112)
            VStack(alignment: .leading, spacing: 3) {
                Text(lab.title).font(.headline)
                Text(lab.question).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                Text("\(lab.options.count) options").font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// One topic: the question, Apple's suggestion, and every option with a picture.
struct TopicView: View {
    let lab: LabID
    let zoom: Namespace.ID
    @Environment(AppRouter.self) private var router
    @AppStorage("duolab.thumbnailPose") private var poseRaw = PreviewPose.open.rawValue

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.colorScheme) private var scheme

    private var pose: PreviewPose { PreviewPose(rawValue: poseRaw) ?? .open }
    /// The display the user is on. Its pictures are what an opened option starts from.
    private var display: PreviewPose { sizeClass == .regular ? .open : .folded }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(lab.question).font(.title3.weight(.semibold))
                        Label(lab.guidance, systemImage: "apple.logo")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: 680, alignment: .leading)
                    LazyVGrid(columns: evenColumns(for: proxy.size.width - 40, minimum: pose == .open ? 300 : 190, spacing: 20),
                              alignment: .leading, spacing: 26) {
                        ForEach(lab.options) { option in
                            OptionCard(lab: lab, option: option, pose: pose, zoom: zoom)
                        }
                    }
                    VerdictLegend()
                }
                .padding(20)
            }
        }
        .navigationTitle(lab.title)
        // Pictures of this display too, even while the switch shows the other one: opening an
        // option then starts from its picture instead of a half-laid-out first frame.
        .task(id: "\(display.rawValue)-\(scheme == .dark)") {
            guard display != pose else { return }
            try? await Task.sleep(for: .milliseconds(600)) // after the visible cards have queued
            for option in lab.options {
                ThumbnailRenderer.shared.request(lab: lab, values: option.knobs, pose: display, scheme: scheme)
            }
        }
        .toolbar {
            ToolbarItem {
                Picker("Show", selection: $poseRaw) {
                    ForEach(PreviewPose.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            // The segmented control draws its own glass; the toolbar's capsule would add a second border.
            .sharedBackgroundVisibility(.hidden)
        }
    }
}

private struct OptionCard: View {
    let lab: LabID
    let option: LabOption
    let pose: PreviewPose
    let zoom: Namespace.ID
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.colorScheme) private var scheme
    @State private var opening = false

    var body: some View {
        let target = PreviewTarget(lab: lab, optionID: option.id)
        Button { open(target) } label: {
            VStack(alignment: .leading, spacing: 10) {
                OptionThumbnail(lab: lab, option: option, pose: pose)
                    .matchedTransitionSource(id: target.id, in: zoom)
                VStack(alignment: .leading, spacing: 3) {
                    Text(option.verdict.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(option.verdict.color)
                    Text(option.title).font(.headline)
                    Text(option.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3, reservesSpace: true)
                }
                .padding(.horizontal, 2)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func open(_ target: PreviewTarget) {
        guard !opening else { return }
        var target = target
        let display: PreviewPose = sizeClass == .regular ? .open : .folded
        if display == pose {
            target.entrance = .zoom
            router.preview = target
            return
        }
        // The card shows the other display. Ask for this display's picture first in line and
        // give it 150 ms: if it arrives, the screen opens on it; if not, it fades in as before.
        opening = true
        let renderer = ThumbnailRenderer.shared
        let key = ThumbnailRenderer.key(lab: lab, values: option.knobs, pose: display, scheme: scheme)
        renderer.request(lab: lab, values: option.knobs, pose: display, scheme: scheme, urgent: true)
        Task {
            let deadline = ContinuousClock.now + .milliseconds(150)
            while renderer.images[key] == nil, ContinuousClock.now < deadline {
                try? await Task.sleep(for: .milliseconds(15))
            }
            opening = false
            // The cover's own slide is switched off; the screen fades itself in (or starts on the picture).
            target.entrance = .fade
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { router.preview = target }
        }
    }
}

/// What the verdict words on each answer mean.
private struct VerdictLegend: View {
    private static let meanings: [(Verdict, String)] = [
        (.recommended, "start here"),
        (.consider, "good in some cases"),
        (.avoid, "shown so you can see why"),
        (.system, "what the system does for you"),
        (.effect, "decoration, never layout"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What the labels mean").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(Self.meanings, id: \.0) { verdict, meaning in
                HStack(spacing: 0) {
                    Text(verdict.title).foregroundStyle(verdict.color).fontWeight(.semibold)
                    Text(" · \(meaning)").foregroundStyle(.secondary)
                }
                .font(.footnote)
            }
        }
        .frame(maxWidth: 680, alignment: .leading)
        .padding(.top, 4)
    }
}

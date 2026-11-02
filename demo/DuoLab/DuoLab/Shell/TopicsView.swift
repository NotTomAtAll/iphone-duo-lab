import SwiftUI

/// Main page: the ten topics as a list. Tap one to see its options.
struct TopicsView: View {
    @Environment(AppRouter.self) private var router
    @Namespace private var zoom

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            List {
                Section {
                    Text("Fourteen layout questions for a foldable. Open one to see the possible answers, then try each answer full screen.")
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
                }
                Section {
                    ForEach(LabID.allCases.filter { $0.options.first?.id != "placeholder" }) { lab in
                        NavigationLink(value: lab) { TopicRow(lab: lab) }
                    }
                }
            }
            .navigationTitle("iPhone Duo")
            .navigationDestination(for: LabID.self) { TopicView(lab: $0, zoom: zoom) }
        }
        .fullScreenCover(item: $router.preview) { target in
            switch target.entrance {
            case .zoom:
                PreviewScreen(target: target)
                    .navigationTransition(.zoom(sourceID: target.id, in: zoom))
            case .fade:
                PreviewScreen(target: target)
                    .presentationBackground(.clear)
            case .system:
                PreviewScreen(target: target)
            }
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
                Text(lab.question).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
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

    private var pose: PreviewPose { PreviewPose(rawValue: poseRaw) ?? .open }

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
                }
                .padding(20)
            }
        }
        .navigationTitle(lab.title)
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
        var target = target
        let display: PreviewPose = sizeClass == .regular ? .open : .folded
        if display == pose {
            target.entrance = .zoom
            router.preview = target
        } else {
            // The cover's own slide is switched off; the screen fades itself in.
            target.entrance = .fade
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { router.preview = target }
        }
    }
}

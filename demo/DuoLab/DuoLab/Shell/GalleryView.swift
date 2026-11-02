import SwiftUI

/// Home: every topic as a section, its options in a row you scroll sideways.
struct GalleryView: View {
    @Environment(AppRouter.self) private var router
    @Environment(DecisionStore.self) private var decisions
    @AppStorage("duolab.thumbnailPose") private var poseRaw = PreviewPose.open.rawValue
    @Namespace private var zoom

    private var pose: PreviewPose { PreviewPose(rawValue: poseRaw) ?? .open }

    var body: some View {
        @Bindable var router = router
        NavigationStack {
            ScrollViewReader { reader in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 36) {
                        header
                        ForEach(LabID.allCases) { lab in
                            TopicRow(lab: lab, pose: pose, zoom: zoom)
                                .id(lab)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onChange(of: router.focusedTopic) { _, lab in
                    guard let lab else { return }
                    withAnimation { reader.scrollTo(lab, anchor: .top) }
                    router.focusedTopic = nil
                }
            }
            .navigationTitle("iPhone Duo")
            .toolbar {
                ToolbarItem {
                    Picker("Show", selection: $poseRaw) {
                        ForEach(PreviewPose.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
            }
        }
        .fullScreenCover(item: $router.preview) { target in
            PreviewScreen(target: target)
                .navigationTransition(.zoom(sourceID: target.id, in: zoom))
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ten layout questions for a foldable. Tap an answer to try it full screen, then tap **Use this** on the one you like.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: 620, alignment: .leading)
            if decisions.decidedCount > 0 {
                Label("\(decisions.decidedCount) of \(LabID.allCases.count) chosen", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.tint)
            }
        }
        .padding(.horizontal, 20)
    }
}

/// One topic: title, question, and its options side by side.
private struct TopicRow: View {
    let lab: LabID
    let pose: PreviewPose
    let zoom: Namespace.ID

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(lab.title).font(.title2.bold())
                Text(lab.question).font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 16) {
                    ForEach(lab.options) { option in
                        OptionCard(lab: lab, option: option, pose: pose, zoom: zoom)
                            .frame(width: pose == .open ? 300 : 170)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
        }
    }
}

struct OptionCard: View {
    let lab: LabID
    let option: LabOption
    let pose: PreviewPose
    let zoom: Namespace.ID
    @Environment(AppRouter.self) private var router
    @Environment(DecisionStore.self) private var decisions

    var body: some View {
        let chosen = decisions.isChosen(option, in: lab)
        let target = PreviewTarget(lab: lab, optionID: option.id)
        Button { router.preview = target } label: {
            VStack(alignment: .leading, spacing: 10) {
                OptionThumbnail(lab: lab, option: option, pose: pose,
                                tweaks: chosen ? decisions.decision(for: lab)?.tweaks ?? [:] : [:])
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(chosen ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), lineWidth: 3)
                    }
                    .overlay(alignment: .topTrailing) {
                        if chosen {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .tint)
                                .padding(8)
                        }
                    }
                    .matchedTransitionSource(id: target.id, in: zoom)
                VStack(alignment: .leading, spacing: 3) {
                    Text(option.verdict.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(option.verdict.color)
                    Text(option.title).font(.headline).lineLimit(2)
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
        .contextMenu {
            Button(chosen ? "Don’t use this" : "Use this", systemImage: chosen ? "xmark.circle" : "checkmark.circle") {
                if chosen { decisions.clear(lab) } else { decisions.choose(option, in: lab) }
            }
            Button("Open", systemImage: "arrow.up.left.and.arrow.down.right") { router.preview = target }
        }
    }
}

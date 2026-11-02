import SwiftUI

/// An option running live and full screen, with glass controls to page, learn more and choose.
struct PreviewScreen: View {
    let lab: LabID
    @State private var index: Int
    @State private var state: KnobState
    @State private var showsInfo = false
    @Environment(\.dismiss) private var dismiss

    init(target: PreviewTarget) {
        lab = target.lab
        let index = target.lab.options.firstIndex { $0.id == target.optionID } ?? 0
        _index = State(initialValue: index)
        let state = KnobState(lab: target.lab, values: target.lab.options[index].knobs)
        state.apply(target.knobs)
        _state = State(initialValue: state)
    }

    private var option: LabOption { lab.options[index] }

    var body: some View {
        // A layout split, not an overlay: the option gets a slightly shorter window and the
        // controls sit below it, so none of the option's own bars end up underneath.
        VStack(spacing: 0) {
            LabContent(lab: lab, state: state)
                .id(index)
            PreviewControls(lab: lab, option: option, index: index, state: state,
                            onClose: { dismiss() }, onStep: step, onInfo: { showsInfo = true })
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showsInfo) { OptionInfoSheet(lab: lab, option: option, state: state) }
        .duoChrome()
    }

    private func step(_ delta: Int) {
        let count = lab.options.count
        withAnimation(.snappy) {
            index = (index + delta + count) % count
            state = KnobState(lab: lab, values: lab.options[index].knobs)
        }
    }
}

/// Close · ‹ option › · info · Use this, in Liquid Glass.
struct PreviewControls: View {
    let lab: LabID
    let option: LabOption
    let index: Int
    let state: KnobState
    var onClose: () -> Void
    var onStep: (Int) -> Void
    var onInfo: () -> Void
    @Environment(DecisionStore.self) private var decisions
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        let chosen = decisions.isChosen(option, in: lab)
        VStack(spacing: 10) {
            if let id = option.highlight, let spec = state.spec(id) {
                Picker(spec.title, selection: Binding(get: { state[id] }, set: { state[id] = $0 })) {
                    ForEach(spec.options, id: \.value) { Text($0.label).tag($0.value) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 260)
            }
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    Button("Close", systemImage: "xmark", action: onClose)
                        .labelStyle(.iconOnly)
                        .buttonBorderShape(.circle)
                        .buttonStyle(.glass)
                        .controlSize(.large)

                    HStack(spacing: 2) {
                        Button("Previous", systemImage: "chevron.left") { onStep(-1) }
                            .labelStyle(.iconOnly)
                            .frame(width: 36, height: 44)
                        VStack(spacing: 1) {
                            Text(option.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                            Text("\(index + 1) of \(lab.options.count)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: 240)
                        Button("Next", systemImage: "chevron.right") { onStep(1) }
                            .labelStyle(.iconOnly)
                            .frame(width: 36, height: 44)
                    }
                    .padding(.horizontal, 4)
                    .glassEffect(.regular.interactive(), in: .capsule)

                    Button("About this option", systemImage: "info", action: onInfo)
                        .labelStyle(.iconOnly)
                        .buttonBorderShape(.circle)
                        .buttonStyle(.glass)
                        .controlSize(.large)

                    useButton(chosen: chosen)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.success, trigger: chosen) { _, new in new }
    }

    @ViewBuilder
    private func useButton(chosen: Bool) -> some View {
        let action = {
            withAnimation(.snappy) {
                if chosen { decisions.clear(lab) } else { decisions.choose(option, in: lab, state: state) }
            }
        }
        let title = chosen ? "Using this" : "Use this"
        let symbol = chosen ? "checkmark.circle.fill" : "checkmark.circle"
        if sizeClass == .compact {
            Button(title, systemImage: symbol, action: action)
                .labelStyle(.iconOnly)
                .buttonBorderShape(.circle)
                .buttonStyle(.glassProminent)
                .controlSize(.large)
        } else {
            Button(title, systemImage: symbol, action: action)
                .buttonStyle(.glassProminent)
                .controlSize(.large)
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
        }
    }
}

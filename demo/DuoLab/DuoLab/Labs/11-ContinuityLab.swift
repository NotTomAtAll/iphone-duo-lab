import SwiftUI
import UIKit

enum ContinuityLab {
    static let options: [LabOption] = [
        LabOption("above", "State above the layout switch", .recommended,
                  summary: "The screen keeps what you did in one place that outlives both layouts, so opening or closing only changes how it is shown.",
                  pros: ["Everything survives: selection, scroll, text, keyboard, progress, sheet", "No extra code per field once state lives in the right place"],
                  cons: ["Takes discipline: every new piece of state has to go up, not into the layout"],
                  lookFor: "Type in the note, then open the device. The checklist should be all ticks and the cursor still blinking.",
                  knobs: ["state": "above"], highlight: "sheet"),
        LabOption("restore", "Rebuild, then restore", .consider,
                  summary: "Each layout starts empty and reloads what it can from a saved copy a moment later.",
                  pros: ["Also survives the app being closed", "Works when state can't easily move up"],
                  cons: ["A visible blink while the screen refills", "The keyboard drops: focus isn't saved", "Every field needs saving and loading code"],
                  lookFor: "Fold and watch the detail: it disappears, then comes back. The keyboard does not.",
                  knobs: ["state": "restore"], highlight: "sheet"),
        LabOption("inside", "State inside each layout", .avoid,
                  summary: "The folded and open layouts each keep their own copy of what you did, so switching layout throws it away.",
                  pros: ["Quick to write"],
                  cons: ["Selection, scroll and typed text reset on every fold", "Progress starts over and the sheet closes"],
                  lookFor: "Open the device: the list is back at the top, nothing is selected and the draft is empty.",
                  knobs: ["state": "inside"], highlight: "sheet"),
        LabOption("identity", "Screen rebuilt on every fold", .avoid,
                  summary: "The whole screen is tied to the display size, so a fold makes a brand-new screen.",
                  pros: [],
                  cons: ["Everything resets, even what lives above the layout", "Easy to add by accident while fixing a layout bug"],
                  lookFor: "Fold with the sheet open: it closes and the checklist fills with crosses.",
                  knobs: ["state": "identity", "sheet": "on"], highlight: "sheet"),
    ]

    static let knobs: [KnobSpec] = [
        KnobSpec("state", "Where state lives", options: [
            .init("above", "Above the layout switch"), .init("inside", "Inside each layout"),
            .init("identity", "Screen keyed on size"), .init("restore", "Rebuild and restore"),
        ], note: "HIG: keep functionality and the state of elements the same between displays. A fold resizes the scene; it does not relaunch the app.",
        facts: ["F-6c", "F-3e"]),
        .toggle("sheet", "Start with a sheet open",
                note: "Apple says sheets adapt to every pose. Whether one stays up depends on where the flag that shows it lives.",
                facts: ["F-6c"]),
    ]
}

// MARK: - State

/// Everything the user did on the notes screen.
struct NotesState: Equatable {
    var selection: Int?
    var draft = ""
    var focused = false
    var scrollID: Int?
    var progressStart = Date.now
    var sheet = false

    /// A task already in progress: a row picked, a list scrolled, a half-typed note.
    static func seed(sheet: Bool) -> NotesState {
        NotesState(selection: 8, draft: "Pick up the prints, then call about the", focused: !sheet,
                   scrollID: 5, progressStart: .now.addingTimeInterval(-24), sheet: sheet)
    }
}

enum NotesBranch: String { case compact, regular }

/// Records what each layout shows, and compares before and after a size-class change.
@MainActor
@Observable
final class ContinuityProbe {
    struct Report { var notes: NotesState; var time: Date }

    @ObservationIgnored private var latest: [NotesBranch: Report] = [:]
    @ObservationIgnored private var check: Task<Void, Never>?
    private(set) var before: NotesState?
    private(set) var after: NotesState?
    private(set) var pending = false
    private(set) var change = ""
    var hinge = ""
    /// Whether the keyboard is on screen right now, from the system's keyboard notifications.
    var keyboardUp = false
    /// The keyboard as it was when the check ran, so "focus kept" is not claimed for a closed keyboard.
    private(set) var keyboardAfter = false

    func report(_ branch: NotesBranch, _ notes: NotesState) {
        latest[branch] = Report(notes: notes, time: .now)
    }

    /// A field torn down by a layout change also loses focus; that is not the user dismissing it.
    static var lastLayoutChange = Date.distantPast

    func begin(from old: NotesBranch, to new: NotesBranch) {
        Self.lastLayoutChange = .now
        before = latest[old]?.notes
        after = nil
        pending = true
        change = "\(Self.name(old)) → \(Self.name(new))"
        check?.cancel()
        check = Task { [weak self] in
            // Long enough for a restoring layout to refill and a field to take focus again.
            try? await Task.sleep(for: .milliseconds(1200))
            guard let self, !Task.isCancelled else { return }
            // Every layout reports when it appears, so this is the layout now on screen.
            self.after = self.latest[new]?.notes
            self.keyboardAfter = self.keyboardUp
            self.pending = false
        }
    }

    static func name(_ branch: NotesBranch) -> String { branch == .regular ? "two panes" : "one column" }
}

// MARK: - Lab view

struct ContinuityLabView: View {
    let state: KnobState

    var body: some View {
        ContinuityDemo(strategy: state["state"], sheet: state.isOn("sheet"))
            .id(state.variantKey)
    }
}

private struct ContinuityDemo: View {
    let strategy: String
    let seed: NotesState
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.isThumbnail) private var isThumbnail
    @State private var probe = ContinuityProbe()
    /// The first layout gets the task in progress; any layout built later starts from its own state.
    @State private var seeded = false
    /// Used by "above": the one copy of the state, outside both layouts.
    @State private var notes: NotesState
    /// Used by "restore": a saved copy, standing in for disk.
    @State private var store: NotesState?

    init(strategy: String, sheet: Bool) {
        self.strategy = strategy
        let seed = NotesState.seed(sheet: sheet)
        self.seed = seed
        _notes = State(initialValue: seed)
    }

    private var branch: NotesBranch { sizeClass == .regular ? .regular : .compact }
    private var initial: NotesState { seeded ? NotesState() : seed }

    private var checklist: ChecklistSlot {
        ChecklistSlot(probe: probe, sheetTracked: seed.sheet,
                      example: isThumbnail ? ChecklistCard.example(strategy) : nil)
    }

    var body: some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                // Folded: its own row above the screen, so it never covers the note. The trailing
                // 60 pt stay free for the lab's handle. Two panes put it in the list pane instead.
                if branch == .compact {
                    ChecklistStrip(slot: checklist)
                        .padding(.trailing, 60)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.bar)
                }
            }
            .environment(\.notesChecklist, checklist)
            .onAppear { seeded = true }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                probe.keyboardUp = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                probe.keyboardUp = false
            }
            .onChange(of: sizeClass) { old, new in
                probe.begin(from: old == .regular ? .regular : .compact, to: new == .regular ? .regular : .compact)
            }
            .onHingeChange { _, context in
                probe.hinge = HingeReading(context).status
            }
    }

    @ViewBuilder
    private var content: some View {
        switch strategy {
        case "inside":
            if branch == .regular {
                OwnedNotes(branch: .regular, initial: initial, probe: probe, store: nil)
            } else {
                OwnedNotes(branch: .compact, initial: initial, probe: probe, store: nil)
            }
        case "restore":
            if branch == .regular {
                OwnedNotes(branch: .regular, initial: initial, probe: probe, store: $store)
            } else {
                OwnedNotes(branch: .compact, initial: initial, probe: probe, store: $store)
            }
        case "identity":
            IdentityHost(initial: initial, probe: probe)
                .id(sizeClass)
        default:
            NotesSwitch(notes: $notes, probe: probe)
                .sheet(isPresented: isThumbnail ? .constant(false) : $notes.sheet) { NoteOptionsSheet() }
        }
    }
}

/// The size-class switch itself: one column folded, two panes open.
private struct NotesSwitch: View {
    @Binding var notes: NotesState
    let probe: ContinuityProbe
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if sizeClass == .regular {
            NotesLayout(branch: .regular, notes: $notes, probe: probe)
        } else {
            NotesLayout(branch: .compact, notes: $notes, probe: probe)
        }
    }
}

/// "Inside" and "restore": each layout owns its copy of the state.
private struct OwnedNotes: View {
    let branch: NotesBranch
    let probe: ContinuityProbe
    let store: Binding<NotesState?>?
    @State private var notes: NotesState
    @Environment(\.isThumbnail) private var isThumbnail

    init(branch: NotesBranch, initial: NotesState, probe: ContinuityProbe, store: Binding<NotesState?>?) {
        self.branch = branch
        self.probe = probe
        self.store = store
        _notes = State(initialValue: initial)
    }

    var body: some View {
        NotesLayout(branch: branch, notes: $notes, probe: probe)
            .sheet(isPresented: isThumbnail ? .constant(false) : $notes.sheet) { NoteOptionsSheet() }
            .task {
                guard let store else { return }
                guard var saved = store.wrappedValue else {
                    store.wrappedValue = notes
                    return
                }
                // Loading takes a moment, as it would from disk. Focus is not part of the saved copy.
                try? await Task.sleep(for: .milliseconds(350))
                saved.focused = false
                notes = saved
            }
            .onChange(of: notes) { _, new in
                guard let store, store.wrappedValue != nil else { return }
                var copy = new
                copy.focused = false
                store.wrappedValue = copy
            }
    }
}

/// "Identity": state above the switch, but the whole host is keyed on the size class.
private struct IdentityHost: View {
    let probe: ContinuityProbe
    @State private var notes: NotesState
    @Environment(\.isThumbnail) private var isThumbnail

    init(initial: NotesState, probe: ContinuityProbe) {
        self.probe = probe
        _notes = State(initialValue: initial)
    }

    var body: some View {
        NotesSwitch(notes: $notes, probe: probe)
            .sheet(isPresented: isThumbnail ? .constant(false) : $notes.sheet) { NoteOptionsSheet() }
    }
}

// MARK: - Layouts

private struct NotesLayout: View {
    let branch: NotesBranch
    @Binding var notes: NotesState
    let probe: ContinuityProbe
    @Environment(\.notesChecklist) private var checklist

    var body: some View {
        Group {
            if branch == .regular { regular } else { compact }
        }
        .onChange(of: notes, initial: true) { _, new in probe.report(branch, new) }
    }

    private var path: Binding<[Int]> {
        Binding(get: { notes.selection.map { [$0] } ?? [] },
                set: { notes.selection = $0.last })
    }

    private var compact: some View {
        NavigationStack(path: path) {
            NotesList(notes: $notes)
                .navigationTitle("Notes")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: Int.self) { NoteDetail(index: $0, notes: $notes) }
        }
    }

    private var regular: some View {
        RegionReader { size, folds, _ in
            let listWidth = folds.first?.minX ?? min(380, size.width * 0.4)
            HStack(spacing: 0) {
                NavigationStack {
                    NotesList(notes: $notes)
                        .navigationTitle("Notes")
                        .navigationBarTitleDisplayMode(.inline)
                        // In the list pane only, before the fold, so the note stays uncovered.
                        .safeAreaInset(edge: .top, spacing: 0) {
                            if let checklist {
                                ChecklistStrip(slot: checklist).background(.bar)
                            }
                        }
                }
                .frame(width: listWidth)
                Divider()
                NavigationStack {
                    if let selection = notes.selection {
                        NoteDetail(index: selection, notes: $notes)
                    } else {
                        ContentUnavailableView("No note selected", systemImage: "note.text")
                    }
                }
            }
        }
    }
}

private struct NotesList: View {
    @Binding var notes: NotesState

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(0..<40, id: \.self) { index in
                        Button { notes.selection = index } label: {
                            NoteRow(index: index, selected: notes.selection == index)
                        }
                        .buttonStyle(.plain)
                        .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $notes.scrollID, anchor: .top)
            .task {
                // A new scroll view starts at the top; put it back where the state says,
                // once it has laid out its rows.
                let wanted = notes.scrollID
                try? await Task.sleep(for: .milliseconds(60))
                if let id = wanted { proxy.scrollTo(id, anchor: .top) }
            }
            .onChange(of: notes.scrollID) { old, new in
                // A restored value arrives after the list appeared.
                if old == nil, let new { proxy.scrollTo(new, anchor: .top) }
            }
        }
    }
}

private struct NoteRow: View {
    let index: Int
    let selected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Tile(index: index, showsCaption: false).frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Placeholder.name(index)) \(index + 1)").font(.headline)
                Text(Placeholder.sentence).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(height: 64)
        .background(selected ? Color.accentColor.opacity(0.18) : .clear)
        .contentShape(.rect)
    }
}

private struct NoteDetail: View {
    let index: Int
    @Binding var notes: NotesState
    @FocusState private var focus: Bool
    @State private var visible = true
    @Environment(\.isThumbnail) private var isThumbnail

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Tile(index: index).frame(height: 130)
                Text("\(Placeholder.name(index)) \(index + 1)").font(.title.bold())
                TextField("Write a note", text: $notes.draft, axis: .vertical)
                    .lineLimit(3...6)
                    .focused($focus)
                    .padding(12)
                    .background(.fill.tertiary, in: .rect(cornerRadius: 12))
                PlaybackRow(start: notes.progressStart)
                Button("Note options", systemImage: "slider.horizontal.3") { notes.sheet = true }
                    .buttonStyle(.bordered)
                ForEach(Placeholder.paragraphs, id: \.self) { Text($0).foregroundStyle(.secondary) }
            }
            .padding()
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Note")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Ask for focus again when this layout appears, if the user had it.
            guard notes.focused, !isThumbnail else { return }
            try? await Task.sleep(for: .milliseconds(450))
            focus = true
        }
        .onChange(of: focus) { _, now in
            if now {
                notes.focused = true
                return
            }
            // A field that is being torn down also loses focus; only record a real dismissal.
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard Date.now.timeIntervalSince(ContinuityProbe.lastLayoutChange) > 1.5 else { return }
                if visible, !focus { notes.focused = false }
            }
        }
        .onDisappear { visible = false }
        .onAppear { visible = true }
    }
}

/// A fake voice memo that keeps playing.
private struct PlaybackRow: View {
    let start: Date
    private let length: Double = 120

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let elapsed = max(0, context.date.timeIntervalSince(start)).truncatingRemainder(dividingBy: length)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Voice memo", systemImage: "waveform")
                    Spacer()
                    Text(Self.time(elapsed) + " / " + Self.time(length)).monospacedDigit().foregroundStyle(.secondary)
                }
                .font(.subheadline)
                ProgressView(value: elapsed / length)
            }
            .padding(12)
            .background(.fill.quaternary, in: .rect(cornerRadius: 12))
        }
    }

    static func time(_ seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

private struct NoteOptionsSheet: View {
    @State private var pinned = true
    @State private var reminder = false

    var body: some View {
        NavigationStack {
            Form {
                Toggle("Pin to top", isOn: $pinned)
                Toggle("Remind me", isOn: $reminder)
                Label("Share a copy", systemImage: "square.and.arrow.up")
            }
            .navigationTitle("Note options")
            .navigationBarTitleDisplayMode(.inline)
        }
        // Medium only, and the content behind stays usable, so the lab's own controls stay in reach.
        .presentationDetents([.medium])
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
    }
}

// MARK: - Checklist

/// What the checklist needs, handed down so two panes can show it in the list pane.
struct ChecklistSlot {
    let probe: ContinuityProbe
    let sheetTracked: Bool
    let example: [Bool]?
}

extension EnvironmentValues {
    @Entry var notesChecklist: ChecklistSlot? = nil
}

private struct ChecklistStrip: View {
    let slot: ChecklistSlot

    var body: some View {
        ChecklistCard(probe: slot.probe, sheetTracked: slot.sheetTracked, example: slot.example)
            .frame(maxWidth: 420, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ChecklistCard: View {
    let probe: ContinuityProbe
    let sheetTracked: Bool
    /// Thumbnails can't fold, so they show the result this option produces.
    let example: [Bool]?
    @State private var expanded = false

    private static let items = ["Selected row", "Scroll position", "Typed text", "Keyboard focus", "Progress", "Sheet"]

    enum Outcome: Equatable {
        case unchecked, kept, lost
        /// Kept in part, with what is missing.
        case partial(String)
        /// Not part of this test, with why.
        case skipped(String)
    }

    static func example(_ strategy: String) -> [Bool] {
        switch strategy {
        case "above": [true, true, true, true, true, true]
        case "restore": [true, true, true, false, true, true]
        default: [false, false, false, false, false, false]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button { withAnimation(.snappy) { expanded.toggle() } } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checklist")
                    Text(title).font(.caption.weight(.semibold)).lineLimit(1)
                    Spacer(minLength: 4)
                    HStack(spacing: 2) {
                        ForEach(Self.items.indices, id: \.self) { index in icon(outcome(index)).font(.caption2) }
                    }
                    Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.caption2)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint(expanded ? "Hides the details" : "Shows each item")
            if expanded {
                Text(subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                // Two rows of three, so the open card stays short.
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6, alignment: .topLeading), count: 3),
                          alignment: .leading, spacing: 4) {
                    ForEach(Array(Self.items.enumerated()), id: \.offset) { index, item in
                        row(item, outcome: outcome(index))
                    }
                }
            }
        }
        .onAppear { if example != nil { expanded = true } }
        .onChange(of: probe.pending) { _, pending in
            // Show the details when a fold's results come in.
            if !pending, probe.before != nil { withAnimation(.snappy) { expanded = true } }
        }
    }

    private var title: String {
        if example != nil { return "After a fold (example)" }
        if probe.pending { return "Checking…" }
        return probe.before == nil ? "Fold or unfold now" : "After the last fold"
    }

    private var subtitle: String {
        if example != nil { return "Open the option, then fold to test it live." }
        if probe.change.isEmpty { return "Records your state, then checks it after the change." }
        return probe.change + (probe.hinge.isEmpty ? "" : " · hinge \(probe.hinge)")
    }

    private func outcome(_ index: Int) -> Outcome {
        if index == 5, !sheetTracked { return .skipped("not open") }
        if let example { return example[index] ? .kept : .lost }
        guard !probe.pending, let before = probe.before else { return .unchecked }
        guard let after = probe.after else { return .lost }
        switch index {
        case 0: return before.selection == after.selection ? .kept : .lost
        case 1: return before.scrollID == after.scrollID ? .kept : .lost
        case 2: return before.draft == after.draft ? .kept : .lost
        case 3:
            if !before.focused { return after.focused ? .lost : .skipped("not typing") }
            guard after.focused else { return .lost }
            // Only a keyboard that is actually up counts as kept.
            return probe.keyboardAfter ? .kept : .partial("no keyboard")
        case 4: return abs(before.progressStart.timeIntervalSince(after.progressStart)) < 0.5 ? .kept : .lost
        default: return before.sheet == after.sheet ? .kept : .lost
        }
    }

    @ViewBuilder
    private func icon(_ outcome: Outcome) -> some View {
        switch outcome {
        case .unchecked, .skipped: Image(systemName: "circle.dotted").foregroundStyle(.secondary)
        case .kept: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .lost: Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        case .partial: Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
        }
    }

    private func row(_ item: String, outcome: Outcome) -> some View {
        HStack(spacing: 5) {
            icon(outcome)
            VStack(alignment: .leading, spacing: 0) {
                Text(item).font(.caption2).lineLimit(1).minimumScaleFactor(0.8)
                switch outcome {
                case .lost: Text("lost").font(.caption2.weight(.semibold)).foregroundStyle(.red)
                case .partial(let note): Text(note).font(.caption2.weight(.semibold)).foregroundStyle(.orange)
                case .skipped(let note): Text(note).font(.caption2).foregroundStyle(.secondary)
                default: EmptyView()
                }
            }
        }
    }
}

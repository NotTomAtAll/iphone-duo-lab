import SwiftUI

enum ToastsLab {
    static let options: [LabOption] = [
        LabOption("inline", "Show the change itself", .recommended,
                  summary: "No message box: the row changes (a filled bookmark, an Archived tag) and a quiet status line under the buttons says what happened.",
                  pros: ["Nothing covers the content", "Works the same on both displays and in every pose", "The proof stays on screen"],
                  cons: ["Only works when the change is visible somewhere"],
                  lookFor: "Tap Save, Archive and Copy link: the row and the status line change; nothing floats.",
                  highlight: "style"),
        LabOption("pill", "Pill in the pane", .recommended,
                  summary: "A short message at the bottom of the pane the action came from, centred on that pane, clear of the fold and the side rail.",
                  pros: ["Easy to connect with the action", "Never crosses the fold or tucks under the rail", "Moves above the keyboard"],
                  cons: ["Covers a little of the pane for a moment"],
                  lookFor: "Save from the list, then from the detail: each pill sits in its own pane. Book pose: the pill stays on one side of the fold.",
                  knobs: ["style": "pill"], highlight: "style"),
        LabOption("banner", "Banner that pushes content", .consider,
                  summary: "A strip at the top that moves the screen down instead of covering it.",
                  pros: ["Covers nothing", "Right for a state that lasts, like being offline"],
                  cons: ["The whole screen jumps for a small confirmation", "Competes with system notifications at the top"],
                  lookFor: "Tap Save: everything shifts down, then back up.",
                  knobs: ["style": "banner"], highlight: "style"),
        LabOption("centered", "Pill centred on the window", .avoid,
                  summary: "The usual phone pill, centred on the whole window.",
                  pros: ["Familiar from phones"],
                  cons: ["Sits off-centre: the side rail is part of the window", "Its edge can slide under the rail", "Open in book pose, it sits right on the fold"],
                  lookFor: "Closed: the pill's right edge runs under the rail. Book pose: the fold cuts it in half.",
                  knobs: ["style": "centered"], highlight: "style"),
        LabOption("full-width", "Full-width bar", .avoid,
                  summary: "A bar across the whole bottom of the window.",
                  pros: ["Hard to miss"],
                  cons: ["Spans both panes and the fold on the open display", "Too wide to read at a glance"],
                  lookFor: "Open the device: one bar stretches across both panes.",
                  knobs: ["style": "fullWidth"], highlight: "style"),
        LabOption("alert", "Alert box", .avoid,
                  summary: "A system alert that says Saved and waits for OK.",
                  pros: ["The system keeps it off the fold"],
                  cons: ["Stops you for news that needs no answer", "An extra tap every time"],
                  lookFor: "Tap Save three times in a row.",
                  knobs: ["style": "alert"], highlight: "style"),
    ]

    static let knobs: [KnobSpec] = [
        KnobSpec("style", "Confirmation", options: [
            .init("inline", "Inline change"), .init("pill", "Pill in the pane"), .init("banner", "Top banner"),
            .init("centered", "Pill centred on the window"), .init("fullWidth", "Full-width bar"), .init("alert", "Alert"),
        ], note: "Apple ships no toast and prefers status inside the interface. If you float a message, place it in the pane it belongs to, from the live safe area and the fold region, never across them.",
        facts: ["F-3a", "F-3g", "F-6b"]),
    ]
}

// MARK: - Model

private struct ToastItem: Identifiable, Hashable {
    let id: Int
    var saved = false
    var archived = false
    var title: String { Placeholder.name(id) }
}

private enum ToastPane { case list, detail }

private struct ToastMessage: Equatable {
    let id = UUID()
    let text: String
    let symbol: String
    let pane: ToastPane
}

// MARK: - View

struct ToastsLabView: View {
    let state: KnobState
    @Environment(\.isThumbnail) private var isThumbnail
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var items = (0..<12).map { ToastItem(id: $0) }
    @State private var selection: Int? = 0
    @State private var toast: ToastMessage?
    @State private var status = "Nothing changed yet."
    @State private var copied = false
    @State private var showsAlert = false
    @State private var note = ""
    @FocusState private var noteFocused: Bool

    private var style: String { state["style"] }

    /// Capture hook: `-duolab.pinToast 1` shows one confirmation at launch and keeps it up,
    /// so a screenshot can be taken after a pose change (taps only reach the closed display).
    private static let pinsToast = UserDefaults.standard.bool(forKey: "duolab.pinToast")
    private var pinned: Bool { isThumbnail || Self.pinsToast }

    var body: some View {
        NavigationSplitView {
            list
                .navigationTitle("Inbox")
                .overlay { pill(for: .list) }
                .safeAreaInset(edge: .bottom) { statusLine(for: .list) }
        } detail: {
            detail
                .overlay { pill(for: .detail) }
        }
        .safeAreaInset(edge: .top, spacing: 0) { banner }
        .overlay { windowWide }
        .overlay { if isThumbnail && style == "alert" { AlertMock(text: "Saved") } }
        .alert(toast?.text ?? "", isPresented: $showsAlert) {
            Button("OK") { toast = nil }
        }
        .task(id: toast?.id) {
            guard let toast, !pinned, style != "alert" else { return }
            // Long enough to read; longer when VoiceOver is reading it out.
            try? await Task.sleep(for: .seconds(voiceOver ? 5 : 2.5))
            if self.toast == toast {
                withAnimation(.easeOut(duration: 0.2)) { self.toast = nil }
                copied = false
            }
        }
        .onAppear {
            guard pinned else { return }
            perform(.save, on: 0, from: .detail)
        }
    }

    // MARK: Panes

    private var list: some View {
        List(selection: $selection) {
            ForEach(items) { item in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8).fill(Placeholder.color(item.id).gradient)
                        .frame(width: 44, height: 44)
                        .overlay { Image(systemName: Placeholder.symbol(item.id)).foregroundStyle(.white) }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.headline)
                        if item.archived {
                            Text("Archived").font(.caption.bold()).foregroundStyle(.orange)
                        } else {
                            Text(Placeholder.sentence).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    Spacer()
                    Button(item.saved ? "Saved" : "Save", systemImage: item.saved ? "bookmark.fill" : "bookmark") {
                        perform(.save, on: item.id, from: .list)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .contentTransition(.symbolEffect(.replace))
                }
                .opacity(item.archived ? 0.5 : 1)
                .tag(item.id)
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let id = selection, let item = items.first(where: { $0.id == id }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    RoundedRectangle(cornerRadius: 18).fill(Placeholder.color(item.id).gradient)
                        .frame(height: 180)
                        .overlay { Image(systemName: Placeholder.symbol(item.id)).font(.system(size: 54)).foregroundStyle(.white) }
                    Text(item.title).font(.largeTitle.bold())
                    actions(for: item)
                    // Its own row under the buttons, so it never covers them on a short window.
                    statusRow
                    Text(Placeholder.paragraphs[0])
                    HStack {
                        TextField("Add a note", text: $note)
                            .textFieldStyle(.roundedBorder)
                            .focused($noteFocused)
                            .submitLabel(.done)
                            .onSubmit { perform(.note, on: item.id, from: .detail) }
                        Button("Add") { perform(.note, on: item.id, from: .detail) }
                            .buttonStyle(.bordered)
                            .disabled(note.isEmpty)
                    }
                    ForEach(Placeholder.paragraphs.dropFirst(), id: \.self) { Text($0) }
                }
                .padding()
                .frame(maxWidth: 640, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(item.title)
            .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView("Pick an item", systemImage: "tray")
        }
    }

    private func actions(for item: ToastItem) -> some View {
        HStack(spacing: 10) {
            Button(item.saved ? "Saved" : "Save", systemImage: item.saved ? "bookmark.fill" : "bookmark") {
                perform(.save, on: item.id, from: .detail)
            }
            Button(item.archived ? "Archived" : "Archive", systemImage: item.archived ? "archivebox.fill" : "archivebox") {
                perform(.archive, on: item.id, from: .detail)
            }
            Button(copied ? "Copied" : "Copy link", systemImage: copied ? "checkmark" : "link") {
                perform(.copy, on: item.id, from: .detail)
            }
        }
        .buttonStyle(.bordered)
        .contentTransition(.symbolEffect(.replace))
    }

    // MARK: Actions

    private enum Action { case save, archive, copy, note }

    private func perform(_ action: Action, on id: Int, from pane: ToastPane) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let name = items[index].title
        let message: ToastMessage
        switch action {
        case .save:
            items[index].saved.toggle()
            message = items[index].saved
                ? ToastMessage(text: "Saved \(name)", symbol: "bookmark.fill", pane: pane)
                : ToastMessage(text: "Removed \(name) from saved", symbol: "bookmark.slash", pane: pane)
        case .archive:
            items[index].archived.toggle()
            message = ToastMessage(text: items[index].archived ? "Archived \(name)" : "Moved \(name) back to the inbox",
                                   symbol: "archivebox.fill", pane: pane)
        case .copy:
            copied = true
            message = ToastMessage(text: "Link copied", symbol: "link", pane: pane)
        case .note:
            guard !note.isEmpty else { return }
            note = ""
            message = ToastMessage(text: "Note added", symbol: "note.text", pane: pane)
        }
        let count = items.filter(\.saved).count
        status = "\(message.text). \(count) saved."
        withAnimation(.snappy(duration: 0.25)) { toast = message }
        if style == "alert" { showsAlert = true }
        if !isThumbnail {
            AccessibilityNotification.Announcement(message.text).post()
        }
    }

    // MARK: Confirmations

    /// Inline: a quiet status line under the pane the action came from.
    @ViewBuilder
    private func statusLine(for pane: ToastPane) -> some View {
        if style == "inline", (toast?.pane ?? .detail) == pane {
            Text(status)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(.bar)
                .accessibilityAddTraits(.updatesFrequently)
        }
    }

    /// Inline, detail pane: the status sits in the content, right under the action buttons.
    @ViewBuilder
    private var statusRow: some View {
        if style == "inline", (toast?.pane ?? .detail) == .detail {
            Label(status, systemImage: "checkmark.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.fill.quaternary, in: .rect(cornerRadius: 10))
                .accessibilityAddTraits(.updatesFrequently)
        }
    }

    /// Pill: in the source pane, from the live safe area (rail, keyboard) and the fold.
    @ViewBuilder
    private func pill(for pane: ToastPane) -> some View {
        if style == "pill", let toast, toast.pane == pane {
            PaneToastLayer { ToastPill(message: toast) }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    @ViewBuilder
    private var banner: some View {
        if style == "banner", let toast {
            Label(toast.text, systemImage: toast.symbol)
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.tint.opacity(0.18))
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    /// The two avoid cases: measured against the whole window, rail and fold included.
    @ViewBuilder
    private var windowWide: some View {
        if let toast, style == "centered" || style == "fullWidth" {
            GeometryReader { proxy in
                let bottom = proxy.size.height - proxy.safeAreaInsets.bottom - 24
                if style == "centered" {
                    ToastPill(message: toast)
                        .frame(width: min(420, proxy.size.width - 32))
                        .position(x: proxy.size.width / 2, y: bottom - 22)
                } else {
                    Label(toast.text, systemImage: toast.symbol)
                        .font(.subheadline.bold())
                        .frame(width: proxy.size.width, height: 52)
                        .background(.thickMaterial)
                        .position(x: proxy.size.width / 2, y: bottom - 20)
                }
            }
            .ignoresSafeArea(.container, edges: .horizontal)
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }
}

// MARK: - Placement

/// Places its content near the bottom of this pane: inside the live safe area (so off the
/// rail and above the keyboard), on one side of a book fold, or in the top region of a laptop fold.
private struct PaneToastLayer<Content: View>: View {
    @Environment(\.simulatedFold) private var simulatedFold
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { proxy in
            let frame = placement(proxy)
            content
                .frame(width: frame.width)
                .position(x: frame.midX, y: frame.midY)
        }
        .allowsHitTesting(false)
    }

    private func placement(_ proxy: GeometryProxy) -> CGRect {
        // The pane's own frame already stops at the rail, the bars and the keyboard. Its
        // safeAreaInsets do not: inside an overlay they repeat the window's insets (rail 84,
        // bottom 34) although the frame already excludes them, so they are not used here.
        let size = proxy.size
        let height: CGFloat = 48
        var minX: CGFloat = 16
        var maxX = size.width - 16
        var bottom = size.height - 16
        // Thumbnails pass a stand-in fold in window space; convert it to this pane.
        let origin = proxy.frame(in: .global).origin
        let folds = simulatedFold.map { [$0.offsetBy(dx: -origin.x, dy: -origin.y)] }
            ?? proxy.reservedRegions(kind: .division).filter(\.isActive).map(\.frame)
        let bounds = CGRect(origin: .zero, size: size)
        for fold in folds where fold.intersects(bounds) {
            let margin: CGFloat = 12
            if fold.height >= fold.width {
                // Book pose: keep to the wider side; ties go trailing, where the system puts alerts.
                let leading = fold.minX - margin - minX
                let trailing = maxX - (fold.maxX + margin)
                if trailing >= leading { minX = fold.maxX + margin } else { maxX = fold.minX - margin }
            } else {
                // Laptop pose: the top region, just above the fold.
                bottom = min(bottom, fold.minY - margin)
            }
        }
        let width = min(360, max(120, maxX - minX))
        return CGRect(x: (minX + maxX) / 2 - width / 2, y: bottom - height, width: width, height: height)
    }
}

private struct ToastPill: View {
    let message: ToastMessage

    var body: some View {
        Label(message.text, systemImage: message.symbol)
            .font(.subheadline.bold())
            .lineLimit(1)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 48)
            .glassEffect(.regular, in: .capsule)
            .accessibilityElement(children: .combine)
    }
}

/// Thumbnails can't capture a real alert; this stands in for it.
private struct AlertMock: View {
    let text: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
            VStack(spacing: 0) {
                Text(text).font(.headline).padding(20)
                Divider()
                Text("OK").font(.headline).foregroundStyle(.tint).padding(12)
            }
            .frame(width: 270)
            .background(.regularMaterial, in: .rect(cornerRadius: 20))
        }
        .ignoresSafeArea()
    }
}

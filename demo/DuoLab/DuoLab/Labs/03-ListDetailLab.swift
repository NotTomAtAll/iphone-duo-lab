import SwiftUI

enum ListDetailLab {
    static let options: [LabOption] = [
        LabOption("split", "Two columns: list + detail", .recommended,
                  summary: "The list stays on the left and the selected item fills the right. Folded, it becomes a normal push.",
                  pros: ["Uses the big display to show more at once", "Works folded with no extra work"],
                  cons: ["The detail needs an empty state"],
                  lookFor: "Select a row, then fold: the detail stays on screen.",
                  knobs: ["visibility": "all"]),
        LabOption("three-column", "Three columns: folders + list + detail", .consider,
                  summary: "Adds a folders column like Mail or Files. Two columns show when fully open and three in book pose; when hidden, folders slide in from the sidebar button.",
                  pros: ["Great for deep hierarchies such as mail or files", "Folders stay one tap away"],
                  cons: ["Fully open, only two columns show, even when all three are asked for", "Overkill for flat content"],
                  lookFor: "Book pose: folders, list and detail. Fully open: list and detail; tap the sidebar button for folders.",
                  knobs: ["container": "split3", "visibility": "all"]),
        LabOption("prominent-detail", "Detail first, list on demand", .consider,
                  summary: "The item fills the screen; the list slides in when you need it.",
                  pros: ["Content gets the full width"],
                  cons: ["The list is one tap away instead of always visible"],
                  lookFor: "Open the list from the toolbar button and pick a row.",
                  knobs: ["style": "prominentDetail"]),
        LabOption("stack", "One column, push to detail", .avoid,
                  summary: "One list. Tapping an item opens it full screen, as on a regular phone.",
                  pros: ["Identical to the phone"],
                  cons: ["A 951 pt wide list row on the inner display", "Wastes the extra level the display offers"],
                  lookFor: "Open the device: one stretched list.",
                  knobs: ["container": "stack"]),
        LabOption("collapse-keep-detail", "Fold keeps the open item", .recommended,
                  summary: "With an item open, folding shows that item, not the list. Back takes you to the list.",
                  pros: ["You keep your place when you fold", "Back from the item still leads to the list"],
                  cons: ["Needs a rule for when nothing is open (then the list shows)"],
                  lookFor: "Pick an item on the open display, then fold: the same item is on screen, with Back to the list.",
                  knobs: ["visibility": "all", "compactColumn": "detail", "onFold": "detail"]),
        LabOption("collapse-to-list", "Fold goes back to the list", .consider,
                  summary: "Folding always lands on the list, even if an item was open.",
                  pros: ["A predictable starting point"],
                  cons: ["Loses what you were reading", "You have to find and open the item again"],
                  lookFor: "Pick an item on the open display, then fold: the list shows instead of the item.",
                  knobs: ["visibility": "all", "onFold": "list"]),
        LabOption("deep-push", "Deeper levels open in the item pane", .recommended,
                  summary: "A third level opens inside the item pane. The list stays put, and Back sits in that pane.",
                  pros: ["The list stays as a steady anchor", "Folded, you land on the same level with the same Back steps"],
                  cons: ["Long chains get deep; keep them short"],
                  lookFor: "Open a part from the item: the list stays. Back returns to the item. Fold: same level, Back works step by step.",
                  knobs: ["visibility": "all", "compactColumn": "detail", "onFold": "detail", "depth": "push"]),
        LabOption("deep-replace", "Deeper levels take over the screen", .avoid,
                  summary: "Opening a part replaces the whole two-pane view with a single full-width page.",
                  pros: ["Lots of room for the part"],
                  cons: ["The list disappears", "Back jumps out of the whole layout", "Text stretches across the fold"],
                  lookFor: "Open a part: the list is gone and the page spans the fold.",
                  knobs: ["visibility": "all", "depth": "replace"]),
    ]

    static let knobs: [KnobSpec] = [
        KnobSpec("container", "Container", options: [
            .init("stack", "Stack (push)"), .init("split2", "Split, 2 columns"), .init("split3", "Split, 3 columns"),
        ], default: "split2",
        note: "HIG: use the inner display for an extra level of hierarchy. A split view collapses to a stack on the outer display by itself.",
        facts: ["F-4a", "D1"]),
        KnobSpec("visibility", "Column visibility", options: [
            .init("automatic", "Automatic"), .init("all", "All"), .init("doubleColumn", "Double"), .init("detailOnly", "Detail only"),
        ], note: "Starting visibility. Automatic picks per size class.",
        facts: ["F-4a"]),
        KnobSpec("compactColumn", "Folded shows", options: [.init("sidebar", "List"), .init("detail", "Detail")],
                 note: "The column you see when the split collapses on the outer display. Fold with a row selected to see continuity.",
                 facts: ["F-6c"]),
        KnobSpec("style", "Split style", options: [.init("balanced", "Balanced"), .init("prominentDetail", "Prominent detail")],
                 note: "Balanced shrinks the detail to fit the columns; prominent detail overlays them.",
                 facts: []),
        KnobSpec("onFold", "On fold", options: [
            .init("system", "Leave it to the system"), .init("detail", "Show the open item"), .init("list", "Go to the list"),
        ], note: "What the app asks for when the split folds into one column. Google's rule: the item stays if one is open.",
        facts: []),
        KnobSpec("depth", "Third level", options: [
            .init("two", "None"), .init("push", "Push in the item pane"), .init("replace", "Replace the whole view"),
        ], note: "HIG: keep the list as an anchor; deeper levels push inside the detail column.",
        facts: []),
    ]
}

private struct Folder: Identifiable, Hashable {
    let id: Int
    var name: String { ["Inbox", "Projects", "Travel", "Recipes", "Archive"][id] }
    var symbol: String { ["tray", "folder", "airplane", "fork.knife", "archivebox"][id] }
}

struct ListDetailLabView: View {
    let state: KnobState
    @State private var folder: Folder? = Folder(id: 0)
    @State private var item: Int?
    @Environment(\.isThumbnail) private var isThumbnail
    @State private var visibility: NavigationSplitViewVisibility
    @State private var compactColumn: NavigationSplitViewColumn

    init(state: KnobState) {
        self.state = state
        // Initial values matter: the split view reads visibility on its first layout.
        _visibility = State(initialValue: Self.visibility(for: state["visibility"]))
        _compactColumn = State(initialValue: state["compactColumn"] == "detail" ? .detail : .sidebar)
        // Deep options open one level down, so the first frame already shows where level 3 goes.
        _detailPath = State(initialValue: [])
        _replaced = State(initialValue: state["depth"] == "replace" ? Part(item: 2, number: 1) : nil)
    }

    private static func visibility(for value: String) -> NavigationSplitViewVisibility {
        switch value {
        case "all": .all
        case "doubleColumn": .doubleColumn
        case "detailOnly": .detailOnly
        default: .automatic
        }
    }
    @State private var path: [Int] = []
    @State private var detailPath: [Part]
    @State private var replaced: Part?
    @Environment(\.horizontalSizeClass) private var sizeClass

    private let folders = (0..<5).map(Folder.init)

    var body: some View {
        Group {
            switch state["container"] {
            case "stack": stack
            case "split3": styled(threeColumn)
            default:
                if let replaced { replacement(replaced) } else { styled(twoColumn) }
            }
        }
        .onAppear {
            sync()
            // Start with an item selected: an empty detail says nothing about the layout.
            if item == nil, state["container"] != "stack" { item = 2 }
            // Deep option: open one level down once the detail column exists, so the first
            // frame already shows where level 3 goes. A path set in init is dropped by the split.
            if state["depth"] == "push", detailPath.isEmpty, let item {
                Task { detailPath = [Part(item: item, number: 1)] }
            }
        }
        .onChange(of: state.variantKey) { sync() }
        .onChange(of: item) { old, _ in if old != nil { detailPath = [] } }
        .onChange(of: sizeClass) { _, new in
            // Folding collapses the split; ask for the column the option wants on top.
            guard new == .compact else { return }
            switch state["onFold"] {
            case "detail" where item != nil: compactColumn = .detail
            case "list":
                // Asking for the list column alone is not enough: with a selection the
                // collapsed split keeps the item on top. Clearing the selection pops it.
                compactColumn = .sidebar
                item = nil
            default: break
            }
        }
    }

    private func replacement(_ part: Part) -> some View {
        NavigationStack {
            PartView(part: part, links: false)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Items", systemImage: "chevron.backward") { replaced = nil }
                    }
                }
        }
    }

    private func sync() {
        visibility = Self.visibility(for: state["visibility"])
        compactColumn = state["compactColumn"] == "detail" ? .detail : .sidebar
    }

    @ViewBuilder
    private func styled(_ view: some View) -> some View {
        if state["style"] == "prominentDetail" {
            view.navigationSplitViewStyle(.prominentDetail)
        } else {
            view.navigationSplitViewStyle(.balanced)
        }
    }

    private var stack: some View {
        NavigationStack(path: $path) {
            List(0..<30, id: \.self) { index in
                NavigationLink(value: index) { ItemRow(index: index) }
            }
            .navigationTitle("Items")
            .navigationDestination(for: Int.self) { ItemDetail(index: $0) }
        }
    }

    private var twoColumn: some View {
        NavigationSplitView(columnVisibility: $visibility, preferredCompactColumn: $compactColumn) {
            List(0..<30, id: \.self, selection: $item) { index in
                NavigationLink(value: index) { ItemRow(index: index) }
            }
            .navigationTitle("Items")
        } detail: {
            if state["depth"] == "push" {
                NavigationStack(path: $detailPath) {
                    detail.navigationDestination(for: Part.self) { PartView(part: $0, links: true) }
                }
            } else {
                detail
            }
        }
    }

    private var threeColumn: some View {
        NavigationSplitView(columnVisibility: $visibility, preferredCompactColumn: $compactColumn) {
            List(folders, selection: $folder) { folder in
                NavigationLink(value: folder) { Label(folder.name, systemImage: folder.symbol) }
            }
            .navigationTitle("Folders")
            .navigationSplitViewColumnWidth(min: 160, ideal: 190, max: 230)
        } content: {
            List(0..<30, id: \.self, selection: $item) { index in
                NavigationLink(value: index) { ItemRow(index: index + (folder?.id ?? 0) * 3) }
            }
            .navigationTitle(folder?.name ?? "Items")
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            detail
        }
    }

    private var partsMode: PartsMode {
        switch state["depth"] {
        case "push": .push
        case "replace": .replace
        default: .none
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let item {
            ItemDetail(index: item, parts: partsMode) { replaced = $0 }
        } else {
            ContentUnavailableView("Select an item", systemImage: "doc.text",
                                   description: Text("On the inner display the list stays beside the detail."))
        }
    }
}

private struct ItemRow: View {
    let index: Int

    var body: some View {
        HStack(spacing: 12) {
            Tile(index: index, showsCaption: false).frame(width: 44, height: 44)
            VStack(alignment: .leading) {
                Text(Placeholder.name(index)).font(.headline)
                Text("Updated \(index + 1) h ago").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private enum PartsMode { case none, push, replace }

/// A level below the item: part 1 of an item, then part 11 of part 1, and so on.
private struct Part: Hashable {
    let item: Int
    let number: Int

    var title: String { "Part " + String(number).map(String.init).joined(separator: ".") }
    var level: Int { String(number).count + 2 }
}

private struct ItemDetail: View {
    let index: Int
    var parts: PartsMode = .none
    var onReplace: (Part) -> Void = { _ in }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Tile(index: index).frame(height: 240)
                Text(Placeholder.name(index)).font(.largeTitle.bold())
                if parts != .none {
                    PartLinks(parent: Part(item: index, number: 0), mode: parts, onReplace: onReplace)
                }
                ForEach(Placeholder.paragraphs, id: \.self) { Text($0) }
            }
            .padding()
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(Placeholder.name(index))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PartLinks: View {
    let parent: Part
    let mode: PartsMode
    var onReplace: (Part) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(1...3, id: \.self) { n in
                let part = Part(item: parent.item, number: parent.number * 10 + n)
                Group {
                    if mode == .push {
                        NavigationLink(value: part) { row(part) }
                    } else {
                        Button { onReplace(part) } label: { row(part) }
                    }
                }
                .buttonStyle(.plain)
                if n < 3 { Divider() }
            }
        }
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func row(_ part: Part) -> some View {
        HStack {
            Image(systemName: "doc.text").foregroundStyle(.tint)
            Text(part.title)
            Spacer()
            Text("Level \(part.level)").font(.caption).foregroundStyle(.secondary)
            Image(systemName: "chevron.forward").font(.caption.bold()).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

/// Level 3 and below. In the pushed version it links one level further, up to level 5.
private struct PartView: View {
    let part: Part
    let links: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Level \(part.level) · \(Placeholder.name(part.item))")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text(part.title).font(.largeTitle.bold())
                if links, part.level < 5 { PartLinks(parent: part, mode: .push) }
                ForEach(Placeholder.paragraphs, id: \.self) { Text($0) }
            }
            .padding()
            .frame(maxWidth: links ? 640 : .infinity, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(part.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

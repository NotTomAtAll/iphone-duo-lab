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
                  summary: "Adds a folders column like Mail or Files. On the Duo's open display only two fit; folders slide in from the sidebar button.",
                  pros: ["Great for deep hierarchies such as mail or files", "Folders stay one tap away"],
                  cons: ["Never shows all three columns on the 867 pt inner window, even when asked to", "Overkill for flat content"],
                  lookFor: "Open the device: list and detail show; tap the sidebar button for folders.",
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
                 note: "preferredCompactColumn: what you see when the split collapses on the outer display. Fold with a row selected to see continuity.",
                 facts: ["F-6c"]),
        KnobSpec("style", "Split style", options: [.init("balanced", "Balanced"), .init("prominentDetail", "Prominent detail")],
                 note: "Balanced shrinks the detail to fit the columns; prominent detail overlays them.",
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

    private let folders = (0..<5).map(Folder.init)

    var body: some View {
        Group {
            switch state["container"] {
            case "stack": stack
            case "split3": styled(threeColumn)
            default: styled(twoColumn)
            }
        }
        .onAppear {
            sync()
            // Start with an item selected: an empty detail says nothing about the layout.
            if item == nil, state["container"] != "stack" { item = 2 }
        }
        .onChange(of: state.variantKey) { sync() }
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
            detail
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

    @ViewBuilder
    private var detail: some View {
        if let item {
            ItemDetail(index: item)
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

private struct ItemDetail: View {
    let index: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Tile(index: index).frame(height: 240)
                Text(Placeholder.name(index)).font(.largeTitle.bold())
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

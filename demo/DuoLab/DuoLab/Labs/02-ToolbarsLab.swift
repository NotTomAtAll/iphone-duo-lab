import SwiftUI

enum ToolbarsLab {
    static let options: [LabOption] = [
        LabOption("system", "System toolbar", .recommended,
                  summary: "Standard toolbar buttons. When folded they move into the column beside your content.",
                  pros: ["Moves to the side on the outer display by itself", "Glass, overflow and placement handled for you"],
                  cons: ["Less control over exact positions"],
                  lookFor: "Fold the device: actions move into the trailing column, prominent action first."),
        LabOption("system-bottom", "With a bottom toolbar", .consider,
                  summary: "Adds a row of actions at the bottom of the screen.",
                  pros: ["Keeps frequent actions in reach"],
                  cons: ["Competes with the tab bar for space"],
                  lookFor: "Bottom items join the side column when folded.",
                  knobs: ["bottomBar": "on"]),
        LabOption("compact", "Inline title, more actions", .consider,
                  summary: "A small title and four actions, to save height.",
                  pros: ["Saves vertical space on the short outer display"],
                  cons: ["Weaker screen identity", "Overflow kicks in sooner"],
                  lookFor: "Count how many actions stay visible before overflow.",
                  knobs: ["title": "inline", "items": "4"]),
        LabOption("custom", "Custom bar", .avoid,
                  summary: "A toolbar the app draws itself.",
                  pros: ["Pixel control"],
                  cons: ["Never moves to the side", "Looks out of place next to the side column", "No glass look"],
                  lookFor: "Fold the device: the bar stays horizontal while the system rail sits beside it.",
                  knobs: ["bar": "custom"]),
        // B6: what gives way when the side column runs out of room.
        LabOption("nav-default", "Browse screen: actions give way", .recommended,
                  summary: "Tabs and eight actions share the side column. On a browse screen the actions move into the overflow menu first and every tab stays.",
                  pros: ["Every section of the app stays one tap away", "No code: this is what the system does"],
                  cons: ["Less-used actions need two taps"],
                  lookFor: "Folded: all four tabs stay. Only Share, the badged bell and Like stay in the column; the rest, the prominent Compose too, go into the overflow menu. Open, four actions fit. With the keyboard up the tab bar hides (folded) or sits under the keyboard (open), and the same actions stay.",
                  knobs: pressured, highlight: "compress"),
        LabOption("task-prefers-toolbar", "Task screen: tabs give way", .recommended,
                  summary: "An editor tells the system its actions matter more here, so the tab bar shrinks before the actions do.",
                  pros: ["The tools for the job stay visible", "Apple's advice: when space is short, keep either the toolbar or the tab bar"],
                  cons: ["Switching sections takes a step while it is compressed", "Only for task screens; a browse screen should keep its tabs"],
                  lookFor: "Folded: the tab bar shrinks to one button for the current tab (its badge stays), and seven actions fit instead of three, folded and open. Only Delete and Compose are left in the overflow menu.",
                  knobs: pressured.merging(["compress": "toolbar", "title": "inline"]) { $1 }, highlight: "compress"),
        LabOption("priorities", "Keep frequent actions longest", .recommended,
                  summary: "Add-on: mark the frequent and badged actions as important and the rare ones as unimportant, so the right ones are the last to go.",
                  pros: ["The badged action and Share stay on screen", "Delete, Tag and Move leave first"],
                  cons: ["One more thing to keep up to date as actions change"],
                  lookFor: "Folded: Share, the badged bell and Compose stay in the column; Like and everything below it go to the overflow menu. Without priorities Compose is the first to go.",
                  knobs: pressured.merging(["priority": "on"]) { $1 }, highlight: "priority"),
        LabOption("own-more", "Own \u{201C}more\u{201D} menu", .avoid,
                  summary: "The app adds its own \u{201C}more\u{201D} button next to the one the system adds when actions overflow.",
                  pros: ["Fixed grouping of rare actions"],
                  cons: ["Two overflow buttons side by side", "The system can still push the app's own button into its menu: a menu inside a menu"],
                  lookFor: "Folded: the app's own \u{201C}more\u{201D} button ends up inside the system's overflow menu, so its actions sit in a menu inside a menu.",
                  knobs: pressured.merging(["more": "on"]) { $1 }, highlight: "more"),
        LabOption("text-items", "Text-only actions", .avoid,
                  summary: "Actions labelled with words instead of symbols.",
                  pros: ["Explicit labels"],
                  cons: ["Words don't fit a narrow column, so fewer actions fit before overflow", "Labels sit sideways next to round symbol buttons"],
                  lookFor: "Folded: the word buttons don't go into the side column. They stay in a horizontal strip over the content, while the side column holds Compose and an overflow menu whose items have no symbols.",
                  knobs: pressured.merging(["labels": "text"]) { $1 }, highlight: "labels"),
    ]

    /// The B6 setup: a four-tab view and eight actions, one badged. Folded, that alone overflows.
    private static let pressured: [String: String] = ["tabs": "on", "items": "8"]

    static let knobs: [KnobSpec] = [
        KnobSpec("bar", "Bar", options: [.init("system", "System"), .init("custom", "Custom")],
                 note: "Apple: only bars the system builds move to the side. A hand-built bar stays where you put it.",
                 facts: ["F-3c", "F-6a"]),
        KnobSpec("title", "Title", options: [.init("large", "Large"), .init("inline", "Inline")],
                 note: "On a vertical bar the title stays in the content area. Compare how much vertical space each mode costs.",
                 facts: ["F-6a"]),
        .toggle("prominent", "Prominent action", default: true,
                note: "HIG: the top of a vertical bar holds Back/Close, then the prominent action.",
                facts: ["F-6a"]),
        KnobSpec("items", "Toolbar items", options: [.init("2", "2"), .init("4", "4"), .init("6", "6"), .init("8", "8")],
                 note: "Count the items that fit before overflow on the short outer display. The second item carries a badge.",
                 facts: ["F-2c"]),
        .toggle("bottomBar", "Bottom toolbar",
                note: "Bottom-bar items move to the side on the outer display as well.",
                facts: ["F-6a"]),
        .toggle("tabs", "In a tab view",
                note: "Puts the screen inside a four-tab tab view, so tabs and actions compete for the same side column.",
                facts: ["F-3c"]),
        KnobSpec("pressure", "Space pressure", options: [.init("none", "None"), .init("keyboard", "Keyboard")],
                 note: "Shows the keyboard to take height away from the side column. Measured: with the keyboard up the tab bar hides completely, so this tests the actions alone.",
                 facts: ["F-6a"]),
        KnobSpec("compress", "When space runs out",
                 options: [.init("automatic", "System decides"), .init("toolbar", "Keep actions"), .init("tabbar", "Keep tabs")],
                 note: "HIG: when space is limited, preserve either the toolbar or the tab bar. Keep actions suits task screens; browse screens keep their tabs.",
                 facts: ["F-3c"]),
        .toggle("priority", "Priorities",
                note: "Frequent and badged actions are marked high, rare ones low. Items overflow from the bottom of the column up.",
                facts: ["F-3c"]),
        .toggle("more", "Own more menu",
                note: "HIG: don't add an overflow menu by hand; the system adds one when items don't fit. Extra actions belong in that one.",
                facts: ["F-3c"]),
        KnobSpec("labels", "Labels", options: [.init("symbols", "Symbols"), .init("text", "Text")],
                 note: "Give every item a symbol and a title; the title shows in the overflow menu.",
                 facts: ["F-6a"]),
    ]
}

struct ToolbarsLabView: View {
    let state: KnobState

    var body: some View {
        if state["bar"] == "custom" {
            CustomBarDemo(state: state)
        } else if state.isOn("tabs") {
            TabView {
                Tab("Inbox", systemImage: "tray.fill") { SystemBarDemo(state: state) }
                    .badge(2)
                Tab("Library", systemImage: "books.vertical.fill") { OtherTab(title: "Library") }
                Tab("People", systemImage: "person.2.fill") { OtherTab(title: "People") }
                Tab("Settings", systemImage: "gearshape.fill") { OtherTab(title: "Settings") }
            }
        } else {
            SystemBarDemo(state: state)
        }
    }
}

/// One toolbar action. `badge` and `frequent` decide its visibility priority.
private struct DemoAction: Identifiable {
    let symbol: String
    let title: String
    var badge: Int = 0
    var frequent = false
    var rare = false
    var id: String { symbol }
}

private let demoActions: [DemoAction] = [
    DemoAction(symbol: "square.and.arrow.up", title: "Share", frequent: true),
    DemoAction(symbol: "bell", title: "Alerts", badge: 3, frequent: true),
    DemoAction(symbol: "heart", title: "Like"),
    DemoAction(symbol: "bookmark", title: "Save"),
    DemoAction(symbol: "flag", title: "Flag"),
    DemoAction(symbol: "folder", title: "Move", rare: true),
    DemoAction(symbol: "tag", title: "Tag", rare: true),
    DemoAction(symbol: "trash", title: "Delete", rare: true),
]

private struct SystemBarDemo: View {
    let state: KnobState
    @Environment(\.isThumbnail) private var isThumbnail
    @FocusState private var typing: Bool
    @State private var draft = ""

    private var actions: [DemoAction] { Array(demoActions.prefix(Int(state["items"]) ?? 2)) }
    /// With its own menu, the app keeps the first half in the bar and puts the rest in the menu.
    private var barActions: [DemoAction] { state.isOn("more") ? Array(actions.prefix(4)) : actions }
    private var menuActions: [DemoAction] { state.isOn("more") ? Array(actions.dropFirst(4)) : [] }

    var body: some View {
        NavigationStack {
            DemoList(header: state["pressure"] == "keyboard" ? AnyView(field) : nil)
                .navigationTitle("Inbox")
                .navigationBarTitleDisplayMode(state["title"] == "large" ? .large : .inline)
                .toolbar {
                    if state.isOn("prominent") {
                        ToolbarItem(placement: .primaryAction) {
                            Button("Compose", systemImage: "square.and.pencil") {}
                                .buttonStyle(.glassProminent)
                        }
                        .visibilityPriority(state.isOn("priority") ? .high : .automatic)
                    }
                    ForEach(barActions) { action in
                        ToolbarItem(placement: state.isOn("tabs") ? .topBarTrailing : .secondaryAction) {
                            actionButton(action)
                        }
                        .visibilityPriority(priority(action))
                    }
                    if !menuActions.isEmpty {
                        ToolbarItem(placement: .topBarTrailing) {
                            Menu("More", systemImage: "ellipsis.circle") {
                                ForEach(menuActions) { action in
                                    Button(action.title, systemImage: action.symbol) {}
                                }
                            }
                        }
                    }
                    if state.isOn("bottomBar") {
                        ToolbarItemGroup(placement: .bottomBar) {
                            Button("Filter", systemImage: "line.3.horizontal.decrease") {}
                            Spacer()
                            Text("12 messages").font(.caption)
                            Spacer()
                            Button("Archive", systemImage: "archivebox") {}
                        }
                    }
                }
                .toolbarVerticalCompressionBehavior(compression)
        }
        .onAppear {
            guard state["pressure"] == "keyboard", !isThumbnail else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                typing = true
            }
        }
    }

    private var field: some View {
        TextField("Reply", text: $draft)
            .focused($typing)
            .textFieldStyle(.roundedBorder)
    }

    @ViewBuilder
    private func actionButton(_ action: DemoAction) -> some View {
        if state["labels"] == "text" {
            Button(action.title) {}.badge(action.badge)
        } else {
            Button(action.title, systemImage: action.symbol) {}.badge(action.badge)
        }
    }

    private func priority(_ action: DemoAction) -> ToolbarItemVisibilityPriority {
        guard state.isOn("priority") else { return .automatic }
        if action.frequent || action.badge > 0 { return .high }
        return action.rare ? .low : .automatic
    }

    private var compression: ToolbarVerticalCompressionBehavior {
        switch state["compress"] {
        case "toolbar": .prefersToolbarItems
        case "tabbar": .prefersTabBar
        default: .automatic
        }
    }
}

private struct OtherTab: View {
    let title: String

    var body: some View {
        NavigationStack {
            DemoList(header: nil).navigationTitle(title)
        }
    }
}

private struct CustomBarDemo: View {
    let state: KnobState

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Text("Inbox").font(state["title"] == "large" ? .largeTitle.bold() : .headline)
                Spacer()
                ForEach(Array(demoActions.prefix(Int(state["items"]) ?? 2))) { action in
                    Image(systemName: action.symbol)
                }
                if state.isOn("prominent") {
                    Image(systemName: "square.and.pencil")
                        .padding(8)
                        .background(.tint, in: .circle)
                        .foregroundStyle(.white)
                }
            }
            .font(.title3)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.bar)
            DemoList(header: nil)
            if state.isOn("bottomBar") {
                HStack {
                    Image(systemName: "line.3.horizontal.decrease")
                    Spacer()
                    Text("12 messages").font(.caption)
                    Spacer()
                    Image(systemName: "archivebox")
                }
                .padding()
                .background(.bar)
            }
        }
    }
}

private struct DemoList: View {
    let header: AnyView?

    var body: some View {
        FoldColumns(count: 30) {
            if let header { header.padding(.horizontal, 16) }
        } row: { index in
            row(index)
        } fallback: {
            List {
                if let header { header }
                ForEach(0..<30, id: \.self) { row($0) }
            }
        }
    }

    private func row(_ index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Placeholder.name(index)).font(.headline)
            Text(Placeholder.sentence).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
        }
    }
}

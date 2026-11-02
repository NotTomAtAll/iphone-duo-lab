import SwiftUI

enum TabBarLab {
    static let options: [LabOption] = [
        LabOption("native", "Native tab bar", .recommended,
                  summary: "The standard tab bar. It stands upright beside your content and moves by itself in every pose.",
                  pros: ["Adapts to every pose with no extra work", "Glass look, a search tab and a separate create button for free", "Your content makes room for it automatically"],
                  cons: ["No long-press or double-tap on tab items", "Badge and title styling is the system's"],
                  lookFor: "Fold and unfold. The bar moves from the trailing rail to the bottom of the inner display."),
        LabOption("sidebar", "Sidebar when open", .consider,
                  summary: "Tabs turn into a sidebar on the big display and back into tabs when folded.",
                  pros: ["Room for more sections and pinned content", "Feels at home on the large display"],
                  cons: ["Takes width from the content", "The structure changes between folded and open"],
                  lookFor: "Open the device: a sidebar replaces the bar. Fold it: tabs again, same selection.",
                  knobs: ["placement": "sidebar", "style": "sidebarAdaptable"]),
        LabOption("minimize", "Minimize on scroll", .avoid,
                  summary: "Asks the bar to shrink while you scroll. On iPhone Duo it does nothing: the bar is vertical and never minimizes.",
                  pros: ["Works on other iPhones, where the bar sits at the bottom"],
                  cons: ["No effect on iPhone Duo in any pose (tested on the iOS 27.1 simulator)", "Don't count on it to free space on the short outer display"],
                  lookFor: "Scroll the Feed down: the vertical bar stays exactly as it is.",
                  knobs: ["minimize": "onScrollDown"]),
        LabOption("accessory", "Bottom accessory", .consider,
                  summary: "A small strip above the tabs, the way music apps show what\u{2019}s playing.",
                  pros: ["The system places it in every pose"],
                  cons: ["Global to all tabs", "Not draggable, so not a picture-in-picture replacement"],
                  lookFor: "Where the accessory goes when the bar turns vertical.",
                  knobs: ["accessory": "on"]),
        LabOption("hide-on-push", "Hide bar on detail", .consider,
                  summary: "The tab bar disappears when you open an item, for a full-screen detail.",
                  pros: ["Full height for detail content"],
                  cons: ["Swipe-back glitches are reported on iOS 26.x", "Users lose the bar mid-flow"],
                  lookFor: "Open a Feed row, then swipe back slowly.",
                  knobs: ["hideOnPush": "on"]),
    ]

    static let knobs: [KnobSpec] = [
        KnobSpec("placement", "Default placement", options: [
            .init("automatic", "Automatic"), .init("tabBar", "Tab bar"), .init("sidebar", "Sidebar"),
        ], note: "Apple: the bottom bar is the default on both Duo displays; a sidebar on the inner display is opt-in. Watch the bar go vertical on the outer display and in inner landscape.",
        facts: ["T-6", "T-31", "F-6a", "D12"]),
        KnobSpec("style", "TabView style", options: [
            .init("automatic", "Automatic"), .init("sidebarAdaptable", "Sidebar adaptable"), .init("tabBarOnly", "Tab bar only"),
        ], note: "defaultTabBarPlacement only acts when the style is sidebarAdaptable. Tab bar only disables the sidebar everywhere.",
        facts: ["T-4", "T-6"]),
        KnobSpec("minimize", "Minimize on scroll", options: [
            .init("automatic", "Automatic"), .init("never", "Never"), .init("onScrollDown", "On scroll down"), .init("onScrollUp", "On scroll up"),
        ], note: "Liquid Glass bars can shrink while you scroll the Feed tab. Check what a vertical bar does with it.",
        facts: ["T-7", "T-15"]),
        .toggle("accessory", "Bottom accessory",
                note: "A mini-player style bar above the tab bar, shared by all tabs. Not draggable; not a PIP replacement.",
                facts: ["T-8", "D8"]),
        .toggle("badges", "Badges", default: true,
                note: "Tab.badge takes numbers or text. See where badges sit when the bar is vertical.",
                facts: ["T-10"]),
        .toggle("roles", "Search + prominent roles", default: true,
                note: "The search tab moves to the trailing end; a prominent tab sits apart (iOS 27).",
                facts: ["T-2", "T-3"]),
        .toggle("hideOnPush", "Hide bar on pushed screen",
                note: "toolbarVisibility(.hidden, for: .tabBar) on the pushed view. Swipe back and watch for glitches.",
                facts: ["T-17", "T-18", "D7"]),
    ]
}

private enum DemoTab: Hashable {
    case feed, library, inbox, create, search
}

struct TabBarLabView: View {
    let state: KnobState
    @State private var selection: DemoTab = .feed
    @State private var reselects = 0
    @State private var feedPath: [Int] = []
    @Environment(\.isThumbnail) private var isThumbnail

    /// TabView swallows a repeated selection, so detect re-taps in the binding setter (D6, T-21).
    private var selectionProxy: Binding<DemoTab> {
        Binding(get: { selection }, set: { new in
            if new == selection {
                reselects += 1
                if !feedPath.isEmpty { feedPath.removeAll() }
            }
            selection = new
        })
    }

    var body: some View {
        styled(
            TabView(selection: selectionProxy) {
                Tab("Feed", systemImage: "rectangle.stack.fill", value: DemoTab.feed) {
                    FeedTab(path: $feedPath, reselects: reselects, hideOnPush: state.isOn("hideOnPush"))
                }
                .badge(state.isOn("badges") ? 3 : 0)
                Tab("Library", systemImage: "books.vertical.fill", value: DemoTab.library) {
                    SimpleTab(title: "Library", symbol: "books.vertical")
                }
                Tab("Inbox", systemImage: "tray.fill", value: DemoTab.inbox) {
                    SimpleTab(title: "Inbox", symbol: "tray")
                }
                .badge(state.isOn("badges") ? Text("new") : nil)
                if state.isOn("roles") {
                    Tab("Create", systemImage: "plus", value: DemoTab.create, role: .prominent) {
                        SimpleTab(title: "Create", symbol: "plus.circle")
                    }
                    Tab(value: DemoTab.search, role: .search) {
                        SearchTab()
                    }
                }
            }
        )
        .tabBarMinimizeBehavior(minimizeBehavior)
        .onAppear {
            // The miniature shows the pushed screen, where this option makes a difference.
            if isThumbnail, state.isOn("hideOnPush") { feedPath = [2] }
        }
        .defaultTabBarPlacement(placement)
        .tabViewBottomAccessory(isEnabled: state.isOn("accessory")) {
            HStack {
                Image(systemName: "waveform")
                Text("Now playing · Placeholder track").lineLimit(1)
                Spacer()
                Image(systemName: "play.fill")
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func styled(_ view: some View) -> some View {
        switch state["style"] {
        case "sidebarAdaptable": view.tabViewStyle(.sidebarAdaptable)
        case "tabBarOnly": view.tabViewStyle(.tabBarOnly)
        default: view
        }
    }

    private var placement: AdaptableTabBarPlacement {
        switch state["placement"] {
        case "tabBar": .tabBar
        case "sidebar": .sidebar
        default: .automatic
        }
    }

    private var minimizeBehavior: TabBarMinimizeBehavior {
        switch state["minimize"] {
        case "never": .never
        case "onScrollDown": .onScrollDown
        case "onScrollUp": .onScrollUp
        default: .automatic
        }
    }
}

private struct FeedTab: View {
    @Binding var path: [Int]
    let reselects: Int
    let hideOnPush: Bool

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { reader in
                List {
                    ForEach(0..<40, id: \.self) { index in
                        NavigationLink(value: index) {
                            HStack(spacing: 12) {
                                Tile(index: index, showsCaption: false).frame(width: 52, height: 52)
                                VStack(alignment: .leading) {
                                    Text(Placeholder.name(index)).font(.headline)
                                    Text(Placeholder.sentence).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                }
                            }
                        }
                    }
                }
                .onChange(of: reselects) {
                    withAnimation { reader.scrollTo(0, anchor: .top) }
                }
            }
            .navigationTitle("Feed")
            .navigationDestination(for: Int.self) { index in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Tile(index: index).frame(height: 280)
                        Text(Placeholder.paragraphs.joined(separator: "\n\n"))
                    }
                    .padding()
                }
                .navigationTitle(Placeholder.name(index))
                .toolbarVisibility(hideOnPush ? .hidden : .automatic, for: .tabBar)
            }
        }
    }
}

private struct SimpleTab: View {
    let title: String
    let symbol: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(title, systemImage: symbol, description: Text("Placeholder tab."))
                .navigationTitle(title)
        }
    }
}

private struct SearchTab: View {
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List(Placeholder.names.filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }, id: \.self) {
                Text($0)
            }
            .navigationTitle("Search")
            .searchable(text: $query)
        }
    }
}

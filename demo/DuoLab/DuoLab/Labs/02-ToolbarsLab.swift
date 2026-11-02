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
    ]

    static let knobs: [KnobSpec] = [
        KnobSpec("bar", "Bar", options: [.init("system", "System"), .init("custom", "Custom")],
                 note: "Apple: only system containers (NavigationStack + .toolbar) move to the side. A hand-built bar stays where you put it.",
                 facts: ["F-3c", "F-6a"]),
        KnobSpec("title", "Title", options: [.init("large", "Large"), .init("inline", "Inline")],
                 note: "On a vertical bar the title stays in the content area. Compare how much vertical space each mode costs.",
                 facts: ["F-6a"]),
        .toggle("prominent", "Prominent action", default: true,
                note: "HIG: the top of a vertical bar holds Back/Close, then the prominent action.",
                facts: ["F-6a"]),
        KnobSpec("items", "Toolbar items", options: [.init("2", "2"), .init("4", "4"), .init("6", "6")],
                 note: "Count the items that fit before overflow on the short outer display.",
                 facts: ["F-2c"]),
        .toggle("bottomBar", "Bottom toolbar",
                note: "Items in .bottomBar move to the side on the outer display as well.",
                facts: ["F-6a"]),
    ]
}

struct ToolbarsLabView: View {
    let state: KnobState

    var body: some View {
        if state["bar"] == "custom" {
            CustomBarDemo(state: state)
        } else {
            SystemBarDemo(state: state)
        }
    }
}

private let toolbarSymbols = ["square.and.arrow.up", "heart", "bookmark", "ellipsis.circle", "trash", "flag"]

private struct SystemBarDemo: View {
    let state: KnobState

    var body: some View {
        NavigationStack {
            DemoList(caption: "System bar: watch it go vertical on the outer display and in inner landscape.")
                .navigationTitle("Inbox")
                .navigationBarTitleDisplayMode(state["title"] == "large" ? .large : .inline)
                .toolbar {
                    if state.isOn("prominent") {
                        ToolbarItem(placement: .primaryAction) {
                            Button("Compose", systemImage: "square.and.pencil") {}
                                .buttonStyle(.glassProminent)
                        }
                    }
                    ForEach(Array(toolbarSymbols.prefix(Int(state["items"]) ?? 2).enumerated()), id: \.offset) { _, symbol in
                        ToolbarItem(placement: .secondaryAction) {
                            Button(symbol, systemImage: symbol) {}
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
                ForEach(Array(toolbarSymbols.prefix(Int(state["items"]) ?? 2)), id: \.self) { symbol in
                    Image(systemName: symbol)
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
            DemoList(caption: "Custom bar: it never moves to the side, so the system rail sits next to a horizontal bar.")
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
    let caption: String

    var body: some View {
        List {
            ForEach(0..<30, id: \.self) { index in
                VStack(alignment: .leading, spacing: 4) {
                    Text(Placeholder.name(index)).font(.headline)
                    Text(Placeholder.sentence).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                }
            }
        }
    }
}

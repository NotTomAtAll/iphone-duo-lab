import SwiftUI

enum TwoPanesLab {
    static let options: [LabOption] = [
        LabOption("split-drag", "Two panes, drag across", .recommended,
                  summary: "Photos on one side of the fold, the album on the other. Pick up a photo and drop it anywhere on the album.",
                  pros: ["The second half becomes a second place to put things", "Direct: you see where it lands", "The whole album pane is the target, never the fold"],
                  cons: ["A long drag on the big display can need two hands", "Still needs a tap way to move, for people who can't drag"],
                  lookFor: "Open: drag a photo over the fold and let go anywhere on the album; the album lights up. Folded: drag a photo onto another to reorder.",
                  highlight: "move"),
        LabOption("split-tap", "Two panes, tap to move", .consider,
                  summary: "The same two panes, but you tap photos to pick them, then tap Move.",
                  pros: ["Works with one hand and with VoiceOver", "Moves several photos at once"],
                  cons: ["Two steps instead of one gesture", "Less direct than dragging"],
                  lookFor: "Tap two photos, then Move to album: both jump to the other pane.",
                  knobs: ["move": "menu"], highlight: "move"),
        LabOption("single-push", "One pane, album behind a button", .avoid,
                  summary: "The phone layout stretched: one wide photo grid, and the album on its own screen.",
                  pros: ["Same layout as on the phone"],
                  cons: ["The open display only gets a wider grid", "You can't see the album while choosing", "Every move goes through a menu"],
                  lookFor: "Open: one wide grid. Add a photo from its menu, then open the album to check it arrived.",
                  knobs: ["layout": "single", "move": "menu"], highlight: "layout"),
        LabOption("spanning", "One grid across the fold", .avoid,
                  summary: "One grid and one drop strip run straight across the fold as if it weren't there.",
                  pros: ["The most photos on screen at once"],
                  cons: ["Photos sit in the fold, where they bend and are hard to grab", "The drop strip crosses the fold, so you can drop into the curve"],
                  lookFor: "Book pose: a column of photos bends in the fold. Drop a photo on the strip right at the fold.",
                  knobs: ["layout": "spanning"], highlight: "layout"),
    ]

    static let knobs: [KnobSpec] = [
        KnobSpec("layout", "Layout", options: [
            .init("split", "Two panes around the fold"), .init("single", "One pane, album pushed"),
            .init("spanning", "One grid across the fold"),
        ], note: "HIG: use the extra space for a companion pane, and keep content and controls out of the fold. Dragging through the fold is fine; dropping into it is not.",
        facts: ["F-3a", "F-6b"]),
        KnobSpec("move", "How to move", options: [.init("drag", "Drag and drop"), .init("menu", "Tap or menu")],
                 note: "In-app drag and drop works across the whole window. Offer a tap path too: a long drag on the open display can need two hands.",
                 facts: []),
    ]
}

// MARK: - Fold locator (also used by the keyboard lab)

/// Where the fold is in this view's own space: the reported division in book pose (or the
/// thumbnail's stand-in), else the middle of the window when the open display lies flat.
struct FoldLocator<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    /// The window's middle, in this view's own space.
    @State private var windowMid: CGFloat = 0
    let content: (_ size: CGSize, _ gutter: CGRect?, _ reported: Bool) -> Content

    init(@ViewBuilder content: @escaping (_ size: CGSize, _ gutter: CGRect?, _ reported: Bool) -> Content) {
        self.content = content
    }

    var body: some View {
        RegionReader { size, folds, _ in
            let vertical = folds.first { $0.height > $0.width }
            let estimate: CGRect? = sizeClass == .regular && size.width > 600 && windowMid > 0
                ? CGRect(x: windowMid - 14, y: 0, width: 28, height: size.height) : nil
            content(size, vertical ?? estimate, vertical != nil)
        }
        .background { WindowMidReader(mid: $windowMid) }
    }
}

/// Reads the middle of the hosting window (the physical fold when the open display lies flat).
private struct WindowMidReader: UIViewRepresentable {
    @Binding var mid: CGFloat

    func makeUIView(context: Context) -> Probe {
        let view = Probe()
        view.onChange = { value in Task { @MainActor in mid = value } }
        return view
    }

    func updateUIView(_ uiView: Probe, context: Context) {}

    final class Probe: UIView {
        var onChange: ((CGFloat) -> Void)?
        private var last: CGFloat = -1

        override func didMoveToWindow() {
            super.didMoveToWindow()
            setNeedsLayout()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            guard let window else { return }
            let value = convert(CGPoint(x: window.bounds.midX, y: 0), from: window).x
            guard abs(value - last) > 0.5 else { return }
            last = value
            onChange?(value)
        }
    }
}

/// The fold drawn as a quiet gutter between two panes.
struct FoldGutter: View {
    let reported: Bool

    var body: some View {
        ZStack {
            Rectangle().fill(.fill.quaternary)
            Rectangle().fill(.separator).frame(width: 1)
            Text(reported ? "FOLD" : "FOLD (MIDDLE)")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.tertiary)
                .fixedSize()
                .rotationEffect(.degrees(-90))
        }
        .ignoresSafeArea(edges: .bottom)
        .accessibilityHidden(true)
    }
}

// MARK: - Model

private struct Shelf {
    var photos = Array(0..<18)
    var album = [18, 19]
    var selected: Set<Int> = []
    var status = "Nothing moved yet."

    static func payload(_ id: Int) -> String { "duolab-photo:\(id)" }

    static func id(from payload: String) -> Int? {
        guard payload.hasPrefix("duolab-photo:") else { return nil }
        return Int(payload.dropFirst("duolab-photo:".count))
    }

    func name(_ id: Int) -> String { "\(Placeholder.name(id)) \(id + 1)" }

    /// Puts a photo in the album or back with the photos, before `target` or at the end.
    mutating func place(_ id: Int, inAlbum: Bool, before target: Int? = nil) {
        guard id != target else { return }
        let wasInAlbum = album.contains(id)
        photos.removeAll { $0 == id }
        album.removeAll { $0 == id }
        selected.remove(id)
        if inAlbum {
            let index = target.flatMap { album.firstIndex(of: $0) } ?? album.endIndex
            album.insert(id, at: index)
        } else {
            let index = target.flatMap { photos.firstIndex(of: $0) } ?? photos.endIndex
            photos.insert(id, at: index)
        }
        status = switch (wasInAlbum, inAlbum) {
        case (false, true): "Moved \(name(id)) to the album."
        case (true, false): "Moved \(name(id)) back to photos."
        default: "Moved \(name(id)) to place \((inAlbum ? album : photos).firstIndex(of: id)! + 1)."
        }
    }

    mutating func moveSelected() {
        let ids = photos.filter(selected.contains)
        for id in ids { place(id, inAlbum: true) }
        if ids.count > 1 { status = "Moved \(ids.count) photos to the album." }
    }
}

// MARK: - Lab view

struct TwoPanesLabView: View {
    let state: KnobState

    var body: some View {
        TwoPanesDemo(layout: state["layout"], drags: state["move"] == "drag")
            .id(state.variantKey)
    }
}

private struct TwoPanesDemo: View {
    let layout: String
    let drags: Bool
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.isThumbnail) private var isThumbnail
    @State private var shelf = Shelf()
    @State private var tab = 0

    var body: some View {
        Group {
            switch layout {
            case "single": SinglePush(shelf: $shelf, drags: drags)
            case "spanning": Spanning(shelf: $shelf, drags: drags)
            default:
                if sizeClass == .regular {
                    FoldLocator { size, gutter, reported in
                        split(size: size, gutter: gutter, reported: reported)
                    }
                } else {
                    folded
                }
            }
        }
        .onAppear {
            if isThumbnail, !drags { shelf.selected = [1, 4] }
        }
    }

    @ViewBuilder
    private func split(size: CGSize, gutter: CGRect?, reported: Bool) -> some View {
        let fold = gutter ?? CGRect(x: size.width * 0.55, y: 0, width: 1, height: size.height)
        HStack(spacing: 0) {
            PhotosPane(shelf: $shelf, drags: drags, columns: 4, stagedTarget: nil)
                .frame(width: max(0, fold.minX))
            FoldGutter(reported: reported)
                .frame(width: fold.width)
            AlbumPane(shelf: $shelf, drags: drags, staged: isThumbnail && drags)
        }
        .overlay {
            if isThumbnail && drags {
                DragGhost(index: 2).position(x: fold.midX, y: 210)
            }
        }
    }

    private var folded: some View {
        VStack(spacing: 0) {
            Picker("Pane", selection: $tab) {
                Text("Photos").tag(0)
                Text("Album (\(shelf.album.count))").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            if tab == 0 {
                PhotosPane(shelf: $shelf, drags: drags, columns: 3,
                           stagedTarget: isThumbnail && drags ? 4 : nil)
                    .overlay {
                        if isThumbnail && drags { DragGhost(index: 2).position(x: 150, y: 250) }
                    }
            } else {
                AlbumPane(shelf: $shelf, drags: drags, staged: false)
            }
        }
    }
}

// MARK: - Panes

private struct PhotosPane: View {
    @Binding var shelf: Shelf
    let drags: Bool
    let columns: Int
    /// Thumbnails show a drop in progress on this tile.
    let stagedTarget: Int?
    @State private var targeted = false

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
                ForEach(shelf.photos, id: \.self) { id in
                    PhotoCell(shelf: $shelf, id: id, drags: drags, inAlbum: false, staged: stagedTarget == id)
                }
            }
            .padding(12)
        }
        .background(targeted ? Color.accentColor.opacity(0.10) : .clear)
        .dropDestination(for: String.self) { items, _ in
            // Dropped on the pane, not on a photo: back to the end of the photos.
            let ids = items.compactMap(Shelf.id(from:)).filter { shelf.album.contains($0) }
            for id in ids { shelf.place(id, inAlbum: false) }
            return !ids.isEmpty
        } isTargeted: { targeted = $0 }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                if !drags {
                    Button("Move \(shelf.selected.count) to album", systemImage: "arrow.right.square") {
                        withAnimation(.snappy) { shelf.moveSelected() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(shelf.selected.isEmpty)
                }
                Text(shelf.status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("twopanes.status")
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
    }
}

private struct AlbumPane: View {
    @Binding var shelf: Shelf
    let drags: Bool
    /// Thumbnails show the pane lit up, as during a drag.
    let staged: Bool
    @State private var targeted = false

    private var lit: Bool { targeted || staged }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Album", systemImage: "rectangle.stack.fill").font(.headline)
                    Spacer()
                    Text("\(shelf.album.count) photos").font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)
                ForEach(shelf.album, id: \.self) { id in
                    AlbumRow(shelf: $shelf, id: id, drags: drags)
                }
                if lit {
                    Label("Drop to add", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color.accentColor.opacity(0.12), in: .rect(cornerRadius: 12))
                }
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(lit ? Color.accentColor.opacity(0.08) : Color(.secondarySystemBackground))
        .overlay {
            if lit {
                RoundedRectangle(cornerRadius: 16).strokeBorder(Color.accentColor, lineWidth: 3).padding(4)
            }
        }
        .dropDestination(for: String.self) { items, _ in
            let ids = items.compactMap(Shelf.id(from:)).filter { shelf.photos.contains($0) }
            withAnimation(.snappy) {
                for id in ids { shelf.place(id, inAlbum: true) }
            }
            return !ids.isEmpty
        } isTargeted: { targeted = $0 }
        .animation(.snappy(duration: 0.2), value: lit)
        .accessibilityIdentifier("twopanes.album")
    }
}

private struct PhotoCell: View {
    @Binding var shelf: Shelf
    let id: Int
    let drags: Bool
    let inAlbum: Bool
    let staged: Bool
    @State private var targeted = false

    private var selected: Bool { shelf.selected.contains(id) }

    var body: some View {
        let tile = Tile(index: id, showsCaption: false)
            .aspectRatio(1, contentMode: .fit)
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white, Color.accentColor)
                        .padding(6)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14).strokeBorder(Color.accentColor, lineWidth: selected ? 3 : 0)
            }
            .overlay(alignment: .leading) {
                // Where a reorder drop lands: before this photo.
                if targeted || staged {
                    Capsule().fill(Color.accentColor).frame(width: 4).padding(.vertical, 4).offset(x: -6)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(shelf.name(id))
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("photo.\(id)")
            // A long press starts the drag, so the menu path is offered to assistive tech instead.
            .accessibilityAction(named: "Move to album") {
                withAnimation(.snappy) { shelf.place(id, inAlbum: true) }
            }

        if drags {
            tile
                .draggable(Shelf.payload(id)) { DragGhost(index: id) }
                .dropDestination(for: String.self) { items, _ in
                    let ids = items.compactMap(Shelf.id(from:))
                    withAnimation(.snappy) {
                        for moved in ids { shelf.place(moved, inAlbum: false, before: id) }
                    }
                    return !ids.isEmpty
                } isTargeted: { targeted = $0 }
        } else {
            tile.onTapGesture {
                if selected { shelf.selected.remove(id) } else { shelf.selected.insert(id) }
            }
            .accessibilityAddTraits(.isButton)
        }
    }
}

private struct AlbumRow: View {
    @Binding var shelf: Shelf
    let id: Int
    let drags: Bool

    var body: some View {
        let row = HStack(spacing: 12) {
            Tile(index: id, showsCaption: false).frame(width: 48, height: 48)
            Text(shelf.name(id)).font(.body)
            Spacer(minLength: 0)
            if !drags {
                Button("Move back", systemImage: "arrow.uturn.left") {
                    withAnimation(.snappy) { shelf.place(id, inAlbum: false) }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
            }
        }
        .padding(8)
        .background(.background, in: .rect(cornerRadius: 12))
        .accessibilityIdentifier("album.\(id)")

        if drags {
            row.draggable(Shelf.payload(id)) { DragGhost(index: id) }
        } else {
            row
        }
    }
}

/// The photo under your finger while dragging.
private struct DragGhost: View {
    let index: Int

    var body: some View {
        Tile(index: index, showsCaption: false)
            .frame(width: 86, height: 86)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "hand.point.up.left.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .shadow(radius: 3)
                    .offset(x: 12, y: 14)
            }
            .rotationEffect(.degrees(-6))
            .shadow(color: .black.opacity(0.3), radius: 10, y: 6)
            .allowsHitTesting(false)
    }
}

// MARK: - Avoid layouts

/// One pane; the album lives on a pushed screen and moves go through each photo's menu.
private struct SinglePush: View {
    @Binding var shelf: Shelf
    let drags: Bool
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.isThumbnail) private var isThumbnail

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: sizeClass == .regular ? 150 : 110), spacing: 8)], spacing: 8) {
                    ForEach(shelf.photos, id: \.self) { id in
                        Tile(index: id, showsCaption: false)
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(alignment: .topTrailing) {
                                Menu {
                                    Button("Add to album", systemImage: "rectangle.stack.badge.plus") {
                                        withAnimation(.snappy) { shelf.place(id, inAlbum: true) }
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.white, .black.opacity(0.35))
                                        .padding(6)
                                }
                                .accessibilityLabel("Options for \(shelf.name(id))")
                            }
                            .accessibilityIdentifier("photo.\(id)")
                    }
                }
                .padding(12)
            }
            .overlay(alignment: .topLeading) {
                if isThumbnail { MenuMock().padding(.leading, 80).padding(.top, 50) }
            }
            .safeAreaInset(edge: .bottom) {
                Text(shelf.status).font(.footnote).foregroundStyle(.secondary)
                    .padding(10).frame(maxWidth: .infinity).background(.bar)
            }
            .navigationTitle("Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(value: "album") {
                        Label("Album (\(shelf.album.count))", systemImage: "rectangle.stack")
                    }
                }
            }
            .navigationDestination(for: String.self) { _ in
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(shelf.album, id: \.self) { AlbumRow(shelf: $shelf, id: $0, drags: false) }
                    }
                    .padding(14)
                }
                .background(Color(.secondarySystemBackground))
                .navigationTitle("Album")
            }
        }
    }
}

/// A stand-in for an open menu, for thumbnails.
private struct MenuMock: View {
    var body: some View {
        Label("Add to album", systemImage: "rectangle.stack.badge.plus")
            .font(.body)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: .rect(cornerRadius: 14))
            .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
    }
}

/// One grid and one drop strip straight across the fold.
private struct Spanning: View {
    @Binding var shelf: Shelf
    let drags: Bool
    @State private var targeted = false

    var body: some View {
        FoldLocator { size, gutter, reported in
            VStack(spacing: 0) {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                        ForEach(shelf.photos, id: \.self) { id in
                            PhotoCell(shelf: $shelf, id: id, drags: drags, inAlbum: false, staged: false)
                        }
                    }
                    .padding(12)
                }
                strip
            }
            .overlay {
                // The fold sits on top of whatever is under it.
                if let gutter {
                    Rectangle().fill(.gray.opacity(0.35))
                        .overlay { Text(reported ? "FOLD" : "FOLD (MIDDLE)").font(.caption2.bold()).foregroundStyle(.white).fixedSize().rotationEffect(.degrees(-90)) }
                        .frame(width: gutter.width, height: size.height)
                        .position(x: gutter.midX, y: size.height / 2)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private var strip: some View {
        HStack(spacing: 8) {
            Label("Album", systemImage: "rectangle.stack.fill").font(.headline).fixedSize()
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(shelf.album, id: \.self) { Tile(index: $0, showsCaption: false).frame(width: 44, height: 44) }
                }
            }
            Text(shelf.status).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 76)
        .background(targeted ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground))
        .dropDestination(for: String.self) { items, _ in
            let ids = items.compactMap(Shelf.id(from:)).filter { shelf.photos.contains($0) }
            withAnimation(.snappy) { for id in ids { shelf.place(id, inAlbum: true) } }
            return !ids.isEmpty
        } isTargeted: { targeted = $0 }
        .accessibilityIdentifier("twopanes.strip")
    }
}

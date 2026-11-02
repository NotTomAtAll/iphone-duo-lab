import SwiftUI

enum GridsLab {
    static let options: [LabOption] = [
        LabOption("adaptive-even", "Adaptive grid, even columns", .recommended,
                  summary: "As many columns as fit, in an even number. In book pose the grid splits at the fold, so a gap, not a photo, sits on it.",
                  pros: ["Reflows on every display with no breakpoints", "A gutter, not a tile, lands on the fold"],
                  cons: ["Sometimes one column fewer than would fit", "Needs to know where the fold is, not just the width"],
                  lookFor: "Book pose: 4 columns, with the fold in the gap between the 2nd and 3rd.",
                  knobs: ["layout": "adaptive160", "evenFold": "on"]),
        LabOption("adaptive-large", "Large adaptive tiles", .consider,
                  summary: "Fewer, bigger tiles with room for captions.",
                  pros: ["Room for captions and metadata"],
                  cons: ["1 column folded, only 2 on the inner display"],
                  lookFor: "Compare tile size between the two displays. In book pose there is one column each side of the fold.",
                  knobs: ["layout": "adaptive220", "evenFold": "on"]),
        LabOption("carousel-rows", "Carousel rows", .consider,
                  summary: "Rows you swipe sideways, softly faded at the edges.",
                  pros: ["Good for browsing many categories"],
                  cons: ["Leaves vertical space unused on the inner display"],
                  lookFor: "Look at the trailing edge next to the rail.",
                  knobs: ["layout": "carousel", "edge": "fade", "rows": "2"]),
        LabOption("fixed-two", "Fixed two columns", .avoid,
                  summary: "Always two columns, as designed for a phone.",
                  pros: ["Simple"],
                  cons: ["Giant tiles on the inner display", "A tile sits right on the fold"],
                  lookFor: "Open the device: two huge tiles per row.",
                  knobs: ["layout": "fixed2"]),
        LabOption("carousel-clip", "Clipped carousel", .avoid,
                  summary: "A single sideways row, cut off at the edge.",
                  pros: ["Phone default"],
                  cons: ["Cards are cut off by the rail", "Most of the inner display stays empty"],
                  lookFor: "The last card cut at the rail.",
                  knobs: ["layout": "carousel", "edge": "clip", "rows": "1"]),
    ]

    static let knobs: [KnobSpec] = [
        KnobSpec("layout", "Layout", options: [
            .init("fixed2", "Fixed 2 columns"), .init("fixed3", "Fixed 3 columns"),
            .init("adaptive160", "Adaptive, min 160"), .init("adaptive220", "Adaptive, min 220"),
            .init("carousel", "Carousel"),
        ], default: "adaptive160",
        note: "Fixed counts stretch tiles on the inner display. Adaptive reflows by container width, with no breakpoints (Apple: avoid fixed widths).",
        facts: ["F-4a", "D1"]),
        .toggle("evenFold", "Even columns",
                note: "HIG: prefer an even column count so a gutter, not a tile, lands on the fold. When a fold is reported, the grid splits into one grid each side of it.",
                facts: ["F-6b"]),
        KnobSpec("edge", "Carousel edge", options: [.init("clip", "Clip"), .init("fade", "Fade"), .init("margin", "Content margin")],
                 note: "Carousels are the first thing clipped by a side rail. A fade or a content margin keeps the peek honest.",
                 facts: ["M-1", "R-§1"]),
        KnobSpec("rows", "Carousel rows", options: [.init("1", "1"), .init("2", "2"), .init("3", "3")],
                 note: "On the inner display one carousel row leaves most of the screen empty.",
                 facts: []),
    ]
}

struct GridsLabView: View {
    let state: KnobState

    var body: some View {
        NavigationStack {
            Group {
                if state["layout"] == "carousel" {
                    CarouselDemo(state: state)
                } else {
                    GridDemo(state: state)
                }
            }
            .navigationTitle("Gallery")
        }
    }
}

private struct GridDemo: View {
    let state: KnobState
    private let spacing: CGFloat = 12
    private let margin: CGFloat = 16
    private let count = 60

    var body: some View {
        RegionReader { size, folds, _ in
            ScrollView {
                if let fold = splitFold(folds, size: size) {
                    split(size: size, fold: fold)
                } else {
                    grid(indices: Array(0..<count), columns: columnCount(for: size.width - 2 * margin, evenFold: state.isOn("evenFold")))
                        .padding(margin)
                }
            }
        }
    }

    /// With "Even columns" on and a vertical fold reported, the fold becomes the middle gutter.
    private func splitFold(_ folds: [CGRect], size: CGSize) -> CGRect? {
        guard state.isOn("evenFold"),
              let fold = folds.first(where: { $0.height > $0.width }),
              fold.minX > margin * 2, fold.maxX < size.width - margin * 2 else { return nil }
        return fold
    }

    /// Two grids, one each side of the fold. The narrower side (the rail takes room on the trailing
    /// one) sets the column count and tile size for both, so rows line up and the layout is
    /// symmetric around the fold.
    private func split(size: CGSize, fold: CGRect) -> some View {
        let half = spacing / 2
        let leftWidth = fold.minX - margin - half
        let rightWidth = size.width - fold.maxX - margin - half
        let narrow = min(leftWidth, rightWidth)
        let side = sideColumns(narrow)
        let tile = max((narrow - CGFloat(side - 1) * spacing) / CGFloat(side), 1)
        // Reading order runs across both sides, row by row.
        let perRow = side * 2
        let rows = (count + perRow - 1) / perRow
        let leftIndices = (0..<rows).flatMap { row in (0..<side).map { row * perRow + $0 } }.filter { $0 < count }
        let rightIndices = (0..<rows).flatMap { row in (0..<side).map { row * perRow + side + $0 } }.filter { $0 < count }
        let item = GridItem(.fixed(tile), spacing: spacing)
        return HStack(alignment: .top, spacing: 0) {
            grid(indices: leftIndices, item: item, columns: side)
                .frame(width: leftWidth, alignment: .trailing)
                .padding(.leading, margin)
                .padding(.trailing, half)
            Color.clear.frame(width: fold.width)
            grid(indices: rightIndices, item: item, columns: side)
                .frame(width: rightWidth, alignment: .leading)
                .padding(.leading, half)
                .padding(.trailing, margin)
        }
        .padding(.vertical, margin)
    }

    private func grid(indices: [Int], item: GridItem? = nil, columns: Int) -> some View {
        LazyVGrid(columns: Array(repeating: item ?? GridItem(.flexible(), spacing: spacing), count: columns), spacing: spacing) {
            ForEach(indices, id: \.self) { Tile(index: $0).aspectRatio(1, contentMode: .fit) }
        }
    }

    /// Columns for one side of the fold: fixed layouts split their count, adaptive ones fit their width.
    private func sideColumns(_ width: CGFloat) -> Int {
        switch state["layout"] {
        case "fixed2": 1
        case "fixed3": 2
        default: columnCount(for: width, evenFold: false)
        }
    }

    private func columnCount(for usableWidth: CGFloat, evenFold: Bool) -> Int {
        let usable = max(usableWidth, 1)
        var count: Int
        switch state["layout"] {
        case "fixed2": count = 2
        case "fixed3": count = 3
        case "adaptive220": count = max(1, Int((usable + spacing) / (220 + spacing)))
        default: count = max(1, Int((usable + spacing) / (160 + spacing)))
        }
        if evenFold, count > 1, count % 2 == 1 { count -= 1 }
        return count
    }
}

private struct CarouselDemo: View {
    let state: KnobState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(0..<(Int(state["rows"]) ?? 1), id: \.self) { row in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Row \(row + 1)").font(.title3.bold()).padding(.horizontal)
                        carousel(offset: row * 10)
                    }
                }
            }
            .padding(.vertical)
        }
    }

    @ViewBuilder
    private func carousel(offset: Int) -> some View {
        let scroll = ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(0..<12, id: \.self) { Tile(index: $0 + offset).frame(width: 180, height: 220) }
            }
            .padding(.horizontal, state["edge"] == "margin" ? 0 : 16)
        }
        switch state["edge"] {
        case "fade":
            scroll.mask(
                LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.04),
                                       .init(color: .black, location: 0.92), .init(color: .clear, location: 1)],
                               startPoint: .leading, endPoint: .trailing)
            )
        case "margin":
            scroll.contentMargins(.horizontal, 16, for: .scrollContent)
        default:
            scroll
        }
    }
}

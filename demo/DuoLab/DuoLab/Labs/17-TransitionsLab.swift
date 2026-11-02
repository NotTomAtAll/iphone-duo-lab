import SwiftUI
import UIKit

enum TransitionsLab {
    static let options: [LabOption] = [
        LabOption("zoom", "Zoom from the photo", .recommended,
                  summary: "The photo you tap grows into the full screen; going back shrinks it into its spot in the grid.",
                  pros: ["You always see where the item came from and where it goes back to",
                         "You can grab the open photo and drag it back down",
                         "Back still works as a normal back"],
                  cons: ["If the grid changes while the photo is open (fold, more columns), the way back has to find a new spot"],
                  lookFor: "Tap a photo, then go back. Try a photo next to the fold on the open display, and fold while a photo is open.",
                  knobs: ["style": "zoom"]),
        LabOption("zoom-cover", "Zoom into a full-screen page", .consider,
                  summary: "The same zoom, but the photo opens as a separate full-screen page with a Close button instead of Back.",
                  pros: ["Good for a focused viewer that hides everything else"],
                  cons: ["Covers the side rail too: Close replaces Back", "No back gesture from the edge, only drag down or Close"],
                  lookFor: "Tap a photo: it fills the whole display. Close it and watch it shrink back.",
                  knobs: ["style": "zoomCover"]),
        LabOption("push", "Plain slide in", .consider,
                  summary: "The usual slide from the side. Fine, just less connected to the photo you tapped.",
                  pros: ["Familiar and fast", "Fits a list where the item opens beside it"],
                  cons: ["Nothing ties the new screen to the photo you tapped"],
                  lookFor: "Tap a photo: the page slides in from the side.",
                  knobs: ["style": "push"]),
        LabOption("custom", "Hand-made hero grow", .avoid,
                  summary: "A home-made animation that grows the photo to the full window, right over the side rail and the fold.",
                  pros: ["Total control over the look"],
                  cons: ["Covers the rail, the status bar and the fold", "No Back, no edge swipe, no drag to close",
                         "Has to be rebuilt for every pose and for Reduce Motion"],
                  lookFor: "Tap a photo: it covers the rail and the status bar. Tap again to close.",
                  knobs: ["style": "custom"]),
        LabOption("none", "Instant swap", .avoid,
                  summary: "The new screen appears with no movement at all.",
                  pros: ["Fastest possible"],
                  cons: ["Feels like a jump: nothing shows where you came from"],
                  lookFor: "Tap a photo: the page just appears.",
                  knobs: ["style": "none"]),
    ]

    static let knobs: [KnobSpec] = [
        KnobSpec("style", "Transition", options: [
            .init("zoom", "Zoom"), .init("zoomCover", "Zoom into full screen"), .init("push", "Slide in"),
            .init("custom", "Hand-made grow"), .init("none", "No animation"),
        ], note: "Apple: zoom from the item you tapped for grids and cards; it is interactive and works with Back. Inside a split view, a plain push into the detail column is the better fit.",
        facts: []),
        KnobSpec("speed", "Speed", options: [.init("normal", "Normal"), .init("slow", "Slow (×6)")],
                 note: "Slow stretches every animation in this window six times so you can watch the path. It is a viewing aid, not a setting to ship.",
                 facts: []),
    ]
}

struct TransitionsLabView: View {
    let state: KnobState
    @Namespace private var zoom
    @Namespace private var hero
    @State private var path: [Int] = []
    @State private var cover: CoverItem?
    @State private var heroItem: Int?
    @Environment(\.isThumbnail) private var isThumbnail

    private var style: String { state["style"] }
    private var slow: Bool { state["speed"] == "slow" }

    var body: some View {
        ZStack {
            NavigationStack(path: $path) {
                grid
                    .navigationTitle("Photos")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationDestination(for: Int.self) { index in
                        if style == "zoom" {
                            PhotoDetail(index: index).navigationTransition(.zoom(sourceID: index, in: zoom))
                        } else {
                            PhotoDetail(index: index)
                        }
                    }
            }
            if let heroItem {
                HeroPhoto(index: heroItem)
                    .matchedGeometryEffect(id: heroItem, in: hero)
                    .ignoresSafeArea()
                    .zIndex(1)
                    .onTapGesture { withAnimation(heroAnimation) { self.heroItem = nil } }
            }
        }
        .fullScreenCover(item: $cover) { item in
            NavigationStack {
                PhotoDetail(index: item.id)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close", systemImage: "xmark") { cover = nil }
                        }
                    }
            }
            .navigationTransition(.zoom(sourceID: item.id, in: zoom))
        }
        .background { if !isThumbnail { WindowSpeed(speed: slow && style != "custom" ? 1 / 6 : 1) } }
        .overlay { if isThumbnail { TransitionMock(style: style) } }
        .onChange(of: state.variantKey) {
            path = []
            cover = nil
            heroItem = nil
        }
    }

    /// The hand-made grow is a SwiftUI animation, so "slow" stretches its duration directly.
    private var heroAnimation: Animation { .smooth(duration: slow ? 2.4 : 0.4) }

    private var grid: some View {
        GeometryReader { proxy in
            let count = max(2, Int(proxy.size.width / 150) / 2 * 2)
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: count), spacing: 8) {
                    ForEach(0..<24, id: \.self) { index in
                        Button { open(index) } label: { tile(index) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("photo-\(index)")
                    }
                }
                .padding(12)
            }
        }
    }

    @ViewBuilder
    private func tile(_ index: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        if style == "custom" {
            Group {
                if heroItem == index {
                    shape.fill(.clear)
                } else {
                    Tile(index: index).matchedGeometryEffect(id: index, in: hero)
                }
            }
            .aspectRatio(1, contentMode: .fit)
        } else {
            Tile(index: index)
                .aspectRatio(1, contentMode: .fit)
                .matchedTransitionSource(id: index, in: zoom) { $0.clipShape(shape) }
        }
    }

    private func open(_ index: Int) {
        switch style {
        case "zoomCover": cover = CoverItem(id: index)
        case "custom": withAnimation(heroAnimation) { heroItem = index }
        case "none":
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { path.append(index) }
        default: path.append(index)
        }
    }
}

private struct CoverItem: Identifiable {
    let id: Int
}

private struct PhotoDetail: View {
    let index: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Tile(index: index, showsCaption: false)
                    .aspectRatio(4 / 3, contentMode: .fit)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                Text(Placeholder.name(index)).font(.largeTitle.bold())
                Text(Placeholder.paragraphs[index % Placeholder.paragraphs.count])
                    .frame(maxWidth: 560, alignment: .leading)
            }
            .padding()
        }
        .navigationTitle(Placeholder.name(index))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The hand-made version: the tile itself, stretched to the window, with no bars at all.
private struct HeroPhoto: View {
    let index: Int

    var body: some View {
        Tile(index: index)
            .overlay(alignment: .topLeading) {
                Text("Tap to close")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(24)
            }
    }
}

/// Scales Core Animation time for the whole window, so system transitions can be watched slowly.
/// Reset to normal speed when the lab goes away.
private struct WindowSpeed: UIViewRepresentable {
    let speed: Float

    func makeUIView(context: Context) -> SpeedView { SpeedView() }

    func updateUIView(_ view: SpeedView, context: Context) {
        view.speed = speed
    }

    static func dismantleUIView(_ view: SpeedView, coordinator: ()) {
        view.speed = 1
    }

    final class SpeedView: UIView {
        private weak var attached: UIWindow?

        var speed: Float = 1 { didSet { apply() } }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window == nil { attached?.layer.speed = 1 }
            apply()
        }

        private func apply() {
            guard let window = window ?? attached else { return }
            attached = window
            let layer = window.layer
            guard layer.speed != speed else { return }
            // Keep the layer's clock continuous when the rate changes.
            let now = layer.convertTime(CACurrentMediaTime(), from: nil)
            layer.beginTime = CACurrentMediaTime()
            layer.timeOffset = now
            layer.speed = speed
        }
    }
}

/// A still frame of each transition for the thumbnails (live transitions can't be captured off-screen).
private struct TransitionMock: View {
    let style: String

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            switch style {
            case "zoom":
                // Mid-zoom: the photo halfway between its tile and the full screen.
                card(index: 5)
                    .frame(width: size.width * 0.62, height: size.height * 0.62)
                    .position(x: size.width * 0.45, y: size.height * 0.48)
            case "zoomCover":
                Color.black.opacity(0.35)
                card(index: 5, radius: 30)
                    .frame(width: size.width * 0.82, height: size.height * 0.82)
                    .position(x: size.width / 2, y: size.height / 2)
            case "push":
                // Mid-slide: the new page covers the right half.
                card(index: 5, radius: 0)
                    .frame(width: size.width * 0.55, height: size.height)
                    .position(x: size.width * 0.725, y: size.height / 2)
                    .shadow(color: .black.opacity(0.3), radius: 16)
            case "custom":
                Tile(index: 5)
                    .frame(width: size.width, height: size.height)
                    .overlay(alignment: .trailing) {
                        Rectangle().stroke(.red, style: StrokeStyle(lineWidth: 4, dash: [8, 6]))
                            .frame(width: min(84, size.width * 0.12))
                    }
            default:
                card(index: 5, radius: 0).frame(width: size.width, height: size.height)
            }
        }
        .allowsHitTesting(false)
    }

    private func card(index: Int, radius: CGFloat = 18) -> some View {
        VStack(spacing: 0) {
            Tile(index: index, showsCaption: false)
            Rectangle().fill(.background).frame(height: 60)
                .overlay(alignment: .leading) {
                    Capsule().fill(.secondary.opacity(0.3)).frame(width: 120, height: 12).padding(.leading, 16)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

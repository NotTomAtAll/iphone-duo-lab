import SwiftUI

enum NarrowWindowsLab {
    static let options: [LabOption] = [
        LabOption("adaptive", "Follow the window you get", .recommended,
                  summary: "The screen lays itself out from the size of its own window and its size class. Narrow gets one column, wide gets two, short shrinks the hero. The window sizes here are simulated inside the screen.",
                  pros: ["Works in every size the system can hand out", "No special cases for Split View, a keyboard or a pinned video", "Same code on both displays"],
                  cons: ["Every screen has to be checked at its smallest size"],
                  lookFor: "Flip the window size: half and third get one column with the toolbar intact, the real open window gets two, short keeps the toolbar and shrinks the picture.",
                  highlight: "window"),
        LabOption("screen-sized", "Lay out for the screen", .avoid,
                  summary: "The layout is worked out from the display's size, not the window's, so a smaller window shows a slice of a screen that is too big for it. Sizes are simulated.",
                  pros: ["Looks right when the app has the whole display"],
                  cons: ["Half and third windows cut off the right side and the bottom toolbar", "A keyboard or pinned video hides the bottom of the screen", "Breaks the day the system offers a new window size"],
                  lookFor: "Half or third: the second column and the toolbar's last buttons are cut off at the window edge. Short: the bottom toolbar is gone.",
                  knobs: ["layout": "screenSized"], highlight: "window"),
        LabOption("minimum-width-guard", "Refuse small windows", .avoid,
                  summary: "Below a minimum size the screen shows a \"needs more room\" message instead of its content. Apple asks apps to support every size, so this is shown for contrast. Sizes are simulated.",
                  pros: ["Nothing ever looks broken"],
                  cons: ["The app is useless in a third-width or short window", "People see a wall instead of their content", "Apple says to support all sizes"],
                  lookFor: "Third and short windows show the message. Half still fits the 440 pt minimum.",
                  knobs: ["layout": "minimumWidthGuard", "window": "splitThird"], highlight: "window"),
        LabOption("compat-unrebuilt", "Not rebuilt for the new SDK", .system,
                  summary: "What you get if you don't rebuild: an app built before the iOS 27 SDK keeps a familiar phone size and aspect ratio when the device opens, with bars around it. We draw it with the measured 466 × 678 pt outer window.",
                  pros: ["Nothing to do: old builds keep running"],
                  cons: ["Most of the inner display is empty bars", "Phone layout on a tablet-sized screen", "People notice; other platforms fail apps for it"],
                  lookFor: "Open the device: a phone-sized screen in the middle, bars either side, whatever the window size knob says.",
                  knobs: ["layout": "compatUnrebuilt", "window": "compat"], highlight: "window"),
    ]

    static let knobs: [KnobSpec] = [
        KnobSpec("window", "Window size", options: [
            .init("full", "Real window"), .init("splitHalf", "Half 475×669"), .init("splitThird", "Third 317×669"),
            .init("compat", "Compat 466×678"), .init("short", "Short ×405"),
        ], default: "splitHalf",
        note: "Simulated: an app can't resize its own window, so smaller windows are drawn inside the screen. Half and third are fractions of the measured 951 × 669 pt inner window; short takes 264 pt off its height (a keyboard, or a pinned video pushing the app down); compat is the measured 466 × 678 pt outer window, used as the old-SDK size.",
        facts: ["F-2g", "F-2j"]),
        KnobSpec("layout", "Layout", options: [
            .init("adaptive", "From the window"), .init("screenSized", "From the screen"),
            .init("minimumWidthGuard", "Minimum size"), .init("compatUnrebuilt", "Not rebuilt"),
        ],
        note: "Apple: design for the size you are given; with the iOS 27 SDK even the full-screen opt-out still resizes. Apps built with older SDKs keep a phone size and aspect ratio when open. Apple's only letterbox advice is for games: change the aspect ratio rather than add bars.",
        facts: ["F-2g", "F-2j", "F-4b"]),
    ]
}

// MARK: - Simulated window

/// One simulated window: its logical size and what the caption says about it.
private struct SimulatedWindow {
    let size: CGSize
    /// The display the simulated size belongs to. Split and compat sizes only exist on the inner display.
    let screen: CGSize
    let title: String
    let isReal: Bool
    let letterbox: Bool
    /// Height taken off the bottom (keyboard or pinned video), drawn as a block under the window.
    let taken: CGFloat

    static let inner = CGSize(width: 951, height: 669)
    static let compat = CGSize(width: 466, height: 678)

    static func make(_ value: String, real: CGSize) -> SimulatedWindow {
        switch value {
        case "splitHalf":
            SimulatedWindow(size: CGSize(width: 475, height: 669), screen: inner, title: "Half width", isReal: false, letterbox: false, taken: 0)
        case "splitThird":
            SimulatedWindow(size: CGSize(width: 317, height: 669), screen: inner, title: "Third width", isReal: false, letterbox: false, taken: 0)
        case "compat":
            SimulatedWindow(size: compat, screen: inner, title: "Compatibility size", isReal: false, letterbox: true, taken: 0)
        case "short":
            SimulatedWindow(size: CGSize(width: real.width, height: 405), screen: CGSize(width: real.width, height: 669),
                            title: "Short window", isReal: false, letterbox: false, taken: 264)
        default:
            SimulatedWindow(size: real, screen: real, title: "Real window", isReal: true, letterbox: false, taken: 0)
        }
    }

    var sizeClass: UserInterfaceSizeClass { size.width < 600 ? .compact : .regular }
}

struct NarrowWindowsLabView: View {
    let state: KnobState
    @Environment(\.horizontalSizeClass) private var realSizeClass

    var body: some View {
        GeometryReader { proxy in
            let layout = state["layout"]
            // An app that wasn't rebuilt gets the compatibility box whatever the system offers.
            let value = layout == "compatUnrebuilt" ? "compat" : state["window"]
            let window = SimulatedWindow.make(value, real: proxy.size)
            if window.isReal {
                ZStack(alignment: .top) {
                    AppScreen(layout: layout, window: window.size, screen: window.screen)
                        .environment(\.horizontalSizeClass, realSizeClass)
                    SizeCaption(text: "Real window · \(window.size.compact) pt · \(realSizeClass == .regular ? "regular" : "compact") width")
                        .padding(.top, 6)
                }
            } else {
                stage(window, layout: layout, available: proxy.size)
            }
        }
        .background(Color(.systemBackground))
    }

    private func stage(_ window: SimulatedWindow, layout: String, available: CGSize) -> some View {
        // Top: clear of the floating option pill. Bottom: the caption.
        let topRoom: CGFloat = 60
        let captionHeight: CGFloat = 44
        let room = CGSize(width: available.width - 16, height: available.height - topRoom - captionHeight)
        let total = CGSize(width: window.size.width, height: window.size.height + window.taken)
        // The first layout pass can report a zero size; keep the scale finite and positive.
        let fit = min(1, room.width / max(total.width, 1), room.height / max(total.height, 1))
        let scale = fit.isFinite ? max(fit, 0.05) : 1
        let percent = Int((scale * 100).rounded())
        let sizeText = "\(window.size.compact) pt · \(window.sizeClass == .compact ? "compact" : "regular") width" + (percent < 100 ? " · drawn at \(percent)%" : "")
        let caption = layout == "compatUnrebuilt"
            ? "Not rebuilt: \(SimulatedWindow.compat.compact) pt in every pose" + (percent < 100 ? " · drawn at \(percent)%" : "")
            : "\(window.title) · \(sizeText)"

        return ZStack {
            // The rest of the screen: dimmed, or black bars for the compatibility size.
            window.letterbox ? Color.black : Color(white: 0.32)
            VStack(spacing: 0) {
                Color.clear.frame(height: topRoom)
                VStack(spacing: 0) {
                    AppScreen(layout: layout, window: window.size, screen: window.screen)
                        .frame(width: window.size.width, height: window.size.height)
                        .environment(\.horizontalSizeClass, window.sizeClass)
                        .background(Color(.systemBackground))
                        .clipShape(.rect(cornerRadius: window.letterbox ? 0 : 12))
                    if window.taken > 0 {
                        TakenBlock(height: window.taken)
                            .frame(width: window.size.width, height: window.taken)
                    }
                }
                .scaleEffect(scale, anchor: .top)
                .frame(width: total.width * scale, height: total.height * scale, alignment: .top)
                VStack(spacing: 1) {
                    Text("Simulated window size")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Text(caption)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 8)
                .frame(height: captionHeight)
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Simulated window, \(caption)")
    }
}

private struct SizeCaption: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.monospacedDigit())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: .capsule)
    }
}

/// The height a keyboard or a pinned video takes away from the window.
private struct TakenBlock: View {
    let height: CGFloat

    var body: some View {
        ZStack {
            Color(.systemGray3)
            VStack(spacing: 4) {
                Image(systemName: "keyboard").font(.title2)
                Text("\(Int(height)) pt taken by a keyboard or a pinned video")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - The generic app screen

/// A plain app screen: title bar, hero picture, list, bottom toolbar. Hand-drawn so it stays
/// inside the simulated frame instead of attaching to the real window's bars.
private struct AppScreen: View {
    let layout: String
    let window: CGSize
    let screen: CGSize
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        switch layout {
        case "screenSized":
            // Laid out for the display, then cut by the window it actually got.
            AppContent(size: screen, wide: screen.width >= 600)
                .frame(width: screen.width, height: screen.height)
                .frame(width: window.width, height: window.height, alignment: .topLeading)
                .clipped()
        case "minimumWidthGuard":
            if window.width < 440 || window.height < 480 {
                NeedsMoreRoom(size: window)
            } else {
                AppContent(size: window, wide: sizeClass == .regular)
            }
        case "compatUnrebuilt":
            // A phone build: always the phone layout.
            AppContent(size: window, wide: false)
        default:
            AppContent(size: window, wide: sizeClass == .regular)
        }
    }
}

private struct AppContent: View {
    let size: CGSize
    let wide: Bool

    private var short: Bool { size.height < 480 }

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            Divider()
            if wide {
                HStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            hero(height: short ? 140 : min(300, size.height * 0.45))
                            Text(Placeholder.paragraphs[0]).font(.callout).foregroundStyle(.secondary)
                        }
                        .padding(16)
                    }
                    .frame(width: size.width * 0.45)
                    Divider()
                    rows
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        hero(height: short ? 90 : min(200, size.height * 0.3))
                            .padding(16)
                        rowList
                    }
                }
            }
            Divider()
            bottomBar
        }
        .frame(width: size.width, height: size.height)
        .background(Color(.systemBackground))
    }

    private var titleBar: some View {
        HStack(spacing: 14) {
            Text("Places").font(.title2.bold()).lineLimit(1)
            Spacer(minLength: 8)
            Image(systemName: "magnifyingglass")
            Image(systemName: "line.3.horizontal.decrease.circle")
            Image(systemName: "plus.circle.fill").foregroundStyle(Color.accentColor)
        }
        .font(.title3)
        .padding(.horizontal, 16)
        .frame(height: 52)
    }

    private func hero(height: CGFloat) -> some View {
        Tile(index: 2)
            .frame(maxWidth: .infinity)
            .frame(height: height)
    }

    private var rows: some View {
        ScrollView { rowList }
    }

    private var rowList: some View {
        LazyVStack(spacing: 0) {
            ForEach(0..<14, id: \.self) { index in
                HStack(spacing: 12) {
                    Tile(index: index + 5, showsCaption: false).frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Placeholder.name(index)) \(index + 1)").font(.body).lineLimit(1)
                        Text(Placeholder.sentence).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .frame(height: 60)
                Divider().padding(.leading, 72)
            }
        }
    }

    private var bottomBar: some View {
        HStack {
            ForEach(["house", "map", "heart", "square.and.arrow.up", "ellipsis.circle"], id: \.self) { symbol in
                Image(systemName: symbol).frame(maxWidth: .infinity)
            }
        }
        .font(.title3)
        .foregroundStyle(Color.accentColor)
        .frame(height: 50)
        .background(.bar)
    }
}

private struct NeedsMoreRoom: View {
    let size: CGSize

    var body: some View {
        ContentUnavailableView {
            Label("Needs more room", systemImage: "arrow.left.and.right.square")
        } description: {
            Text("Make the window bigger to use this screen. It needs at least 440 × 480 pt; this window is \(size.compact) pt.")
        }
        .frame(width: size.width, height: size.height)
        .background(Color(.secondarySystemBackground))
    }
}

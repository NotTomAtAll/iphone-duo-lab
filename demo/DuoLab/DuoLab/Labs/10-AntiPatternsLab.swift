import SwiftUI
import UIKit

enum AntiPatternsLab {
    static let options: [LabOption] = [
        LabOption("screen-size", "Sizing from the screen", .avoid,
                  summary: "Width taken from the screen instead of the container.",
                  pros: [], cons: ["Runs 84 pt under the rail", "Wrong in every pose"],
                  lookFor: "Switch Broken and Fixed: the banner end moves out of the rail.",
                  knobs: ["pattern": "screenMain"], highlight: "mode"),
        LabOption("symmetric-insets", "Symmetric insets", .avoid,
                  summary: "Width computed as full width minus the leading inset twice.",
                  pros: [], cons: ["The Duo's insets are asymmetric (0 leading, 84 trailing)"],
                  lookFor: "The trailing label disappears under the rail when Broken.",
                  knobs: ["pattern": "symmetric"], highlight: "mode"),
        LabOption("cached-insets", "Insets cached at launch", .avoid,
                  summary: "Safe-area values read once and reused.",
                  pros: [], cons: ["Stale after every fold"],
                  lookFor: "Launch folded, open the device: Broken keeps the folded values.",
                  knobs: ["pattern": "cached"], highlight: "mode"),
        LabOption("orientation", "Layout by orientation", .avoid,
                  summary: "Columns chosen from the phone's rotation.",
                  pros: [], cons: ["The inner display ignores the rotation lock"],
                  lookFor: "Broken picks columns from the rotation; Fixed from the width the screen actually has.",
                  knobs: ["pattern": "orientation"], highlight: "mode"),
        LabOption("clamp", "Clamp to a phone column", .avoid,
                  summary: "The whole app squeezed into 480 pt in the middle.",
                  pros: ["Quick stopgap"], cons: ["Less content than the folded phone", "Dead gutters that do nothing"],
                  lookFor: "Gray gutters on both sides when Broken.",
                  knobs: ["pattern": "clamp"], highlight: "mode"),
    ]

    static let knobs: [KnobSpec] = [
        KnobSpec("pattern", "Pattern", options: [
            .init("screenMain", "Sized from the screen"), .init("symmetric", "Symmetric insets"),
            .init("cached", "Insets cached at launch"), .init("orientation", "Orientation-based layout"),
            .init("clamp", "Clamp app to a phone column"),
        ], note: "Each one works on a normal iPhone and fails on the Duo. Flip Broken/Fixed, then fold and unfold.",
        facts: ["F-3f", "F-3g", "F-2e", "D10", "R-§1"]),
        KnobSpec("mode", "Mode", options: [.init("broken", "Broken"), .init("fixed", "Fixed")],
                 note: "Fixed is the recommended pattern.",
                 facts: ["D1", "D10"]),
    ]
}

/// The first safe area the app saw, kept on purpose to show why caching is wrong.
enum LaunchCache {
    private(set) static var insets: UIEdgeInsets?

    static func captureIfNeeded() {
        guard insets == nil else { return }
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        insets = window?.safeAreaInsets
    }
}

struct AntiPatternsLabView: View {
    let state: KnobState

    private var broken: Bool { state["mode"] == "broken" }

    var body: some View {
        NavigationStack {
            Group {
                switch state["pattern"] {
                case "symmetric": SymmetricInsetsDemo(broken: broken)
                case "cached": CachedInsetsDemo(broken: broken)
                case "orientation": OrientationDemo(broken: broken)
                case "clamp": ClampDemo(broken: broken)
                default: ScreenMainDemo(broken: broken)
                }
            }
            .navigationTitle(broken ? "Broken" : "Fixed")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct Explainer: View {
    let broken: Bool
    let wrong: String
    let right: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(broken ? wrong : right, systemImage: broken ? "xmark.octagon.fill" : "checkmark.seal.fill")
                .foregroundStyle(broken ? .red : .green)
                .font(.subheadline.weight(.semibold))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct ScreenMainDemo: View {
    let broken: Bool

    var body: some View {
        GeometryReader { proxy in
            let width = broken ? currentScreenWidth : proxy.size.width
            VStack(alignment: .leading, spacing: 16) {
                Explainer(broken: broken,
                          wrong: "Banner width = screen width (\(Int(currentScreenWidth)) pt). The window isn't the screen.",
                          right: "Banner width = container width (\(Int(proxy.size.width)) pt), the space the view really has.")
                Tile(index: 3)
                    .frame(width: width, height: 160)
                Text("Container \(Int(proxy.size.width)) pt · screen \(Int(currentScreenWidth)) pt")
                    .font(.caption.monospaced())
            }
            .padding()
        }
    }

    /// Stands in for `UIScreen.main.bounds`, which Apple deprecates for exactly this reason (F-3f).
    private var currentScreenWidth: CGFloat {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        return scene?.screen.bounds.width ?? 0
    }
}

private struct SymmetricInsetsDemo: View {
    let broken: Bool

    var body: some View {
        GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            ZStack(alignment: .topLeading) {
                Color.clear
                if broken {
                    // width − leading × 2, positioned from the leading edge: wrong when the rail is trailing.
                    let width = proxy.size.width + insets.leading + insets.trailing - insets.leading * 2
                    content(insets: insets)
                        .frame(width: width)
                        .offset(x: insets.leading)
                } else {
                    content(insets: insets)
                        .padding(.leading, insets.leading)
                        .padding(.trailing, insets.trailing)
                }
            }
            .ignoresSafeArea(edges: .horizontal)
        }
    }

    private func content(insets: EdgeInsets) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Explainer(broken: broken,
                      wrong: "Width = full − leading × 2. With a trailing rail (L\(Int(insets.leading)) R\(Int(insets.trailing))) the content runs under it.",
                      right: "Pad each edge by its own inset. The Duo's insets are asymmetric.")
            HStack {
                Text("Leading edge")
                Spacer()
                Text("Trailing edge →").bold()
            }
            .padding()
            .background(.orange.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(.vertical)
    }
}

private struct CachedInsetsDemo: View {
    let broken: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The explanation gets its own row in the safe area, so stale insets below can't push it under the title.
            Explainer(broken: broken,
                      wrong: "Uses the insets captured at launch. Fold or unfold and they go stale.",
                      right: "Reads the live safe area on every layout pass.")
                .padding(.horizontal)
                .padding(.vertical, 8)
            GeometryReader { proxy in
                let live = proxy.safeAreaInsets
                let cached = LaunchCache.insets.map {
                    EdgeInsets(top: $0.top, leading: $0.left, bottom: $0.bottom, trailing: $0.right)
                } ?? EdgeInsets()
                let used = broken ? cached : live
                ZStack(alignment: .topLeading) {
                    Color.clear
                    VStack(alignment: .leading, spacing: 12) {
                        Text("launch \(cached.compact)\nlive   \(live.compact)")
                            .font(.caption.monospaced())
                        RoundedRectangle(cornerRadius: 10).fill(.purple.opacity(0.35))
                            .overlay(Text("Content placed with \(broken ? "cached" : "live") insets").font(.headline))
                    }
                    .padding(.top, used.top)
                    .padding(.leading, used.leading)
                    .padding(.trailing, used.trailing)
                    .padding(.bottom, used.bottom)
                    .padding(.horizontal, 8)
                }
                .ignoresSafeArea(edges: [.horizontal, .bottom])
            }
        }
    }
}

private struct OrientationDemo: View {
    let broken: Bool
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        GeometryReader { _ in
            let wide = broken ? isLandscape : sizeClass == .regular
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Explainer(broken: broken,
                              wrong: "Columns picked from the phone's rotation (\(isLandscape ? "landscape" : "portrait")). The inner display ignores the rotation lock.",
                              right: "Columns picked from the width class (\(sizeClass == .regular ? "wide" : "narrow")).")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: wide ? 4 : 2), spacing: 12) {
                        ForEach(0..<16, id: \.self) { Tile(index: $0).aspectRatio(1, contentMode: .fit) }
                    }
                }
                .padding()
            }
        }
    }

    private var isLandscape: Bool {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        return scene?.effectiveGeometry.interfaceOrientation.isLandscape ?? false
    }
}

private struct ClampDemo: View {
    let broken: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Explainer(broken: broken,
                          wrong: "Whole screen clamped to 480 pt: less content than the folded phone, dead gutters, clipped carousels.",
                          right: "Adaptive grid uses the width; only reading screens get a column.")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(0..<24, id: \.self) { Tile(index: $0).aspectRatio(1, contentMode: .fit) }
                }
            }
            .padding()
            .frame(maxWidth: broken ? 480 : .infinity)
            .frame(maxWidth: .infinity)
            .background(broken ? Color.gray.opacity(0.25) : .clear)
        }
    }
}

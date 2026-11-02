import SwiftUI

/// The HUD overlay: reserved regions drawn as tinted boxes, plus a small readout panel.
struct HUDOverlay: View {
    @State private var hinge = HingeReading.unknown

    var body: some View {
        EnvironmentProbe { snapshot in
            ZStack(alignment: .topLeading) {
                Color.clear
                ForEach(snapshot.regions) { region in
                    Rectangle()
                        .fill((region.kind == "division" ? Color.red : Color.orange).opacity(region.isActive ? 0.25 : 0.08))
                        .overlay(Rectangle().strokeBorder(region.kind == "division" ? .red : .orange,
                                                          style: StrokeStyle(lineWidth: 1, dash: region.isActive ? [] : [4, 4])))
                        .frame(width: max(region.frame.width, 2), height: max(region.frame.height, 2))
                        .offset(x: region.frame.minX, y: region.frame.minY)
                }
                SafeAreaOutline(insets: snapshot.safeArea, size: snapshot.size)
                // Bottom-leading keeps the readout off large titles and the centered tab bar.
                readout(snapshot)
                    .padding(.leading, snapshot.safeArea.leading + 8)
                    .padding(.bottom, snapshot.safeArea.bottom + 72) // clears the playground pill and bottom bars
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
        .allowsHitTesting(false)
        .onHingeChange { _, new in hinge = HingeReading(new) }
    }

    private func readout(_ s: EnvironmentSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("size \(s.size.compact)  \(s.sizeClassText)")
            Text("safe \(s.safeArea.compact)")
            Text("hinge \(hinge.status)\(hinge.angle.map { String(format: " %.0f°", $0) } ?? "")")
            Text("fold \(s.fold?.compact ?? "none")  occl \(s.regions.filter { $0.kind == "occlusion" && $0.isActive }.count)")
        }
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .padding(6)
        .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 6))
        .foregroundStyle(.white)
    }
}

/// Dashed outline of the safe area, so you can see which edges are inset.
struct SafeAreaOutline: View {
    let insets: EdgeInsets
    let size: CGSize

    var body: some View {
        Rectangle()
            .strokeBorder(.green.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            .frame(width: max(size.width - insets.leading - insets.trailing, 0),
                   height: max(size.height - insets.top - insets.bottom, 0))
            .offset(x: insets.leading, y: insets.top)
    }
}

/// Thumb reach bands for the current display: our model, not measured (docs/05 §1).
/// Folded: one right thumb from the bottom-trailing corner. Open or book: two thumbs, one from
/// each bottom corner, with the fold marked hard while it is active. Pose comes from the size
/// class and the fold region, never from the hinge angle. The trailing side column is left clear.
struct ReachOverlay: View {
    static let storageKey = "reachOverlay"
    /// Fixed thumb radii in points from the pivot corner; the same thumb on both displays.
    static let easyRadius: CGFloat = 300
    static let stretchRadius: CGFloat = 440

    enum Band: CaseIterable {
        case easy, stretch, hard

        var title: String {
            switch self {
            case .easy: "Easy"
            case .stretch: "Stretch"
            case .hard: "Hard"
            }
        }

        var color: Color {
            switch self {
            case .easy: .green
            case .stretch: .yellow
            case .hard: .red
            }
        }
    }

    var body: some View {
        EnvironmentProbe { snapshot in
            let size = snapshot.size
            let pivots = snapshot.horizontal == .regular
                ? [CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height)]
                : [CGPoint(x: size.width, y: size.height)]
            let content = CGRect(x: snapshot.safeArea.leading, y: 0,
                                 width: max(size.width - snapshot.safeArea.leading - snapshot.safeArea.trailing, 0),
                                 height: size.height)
            ZStack(alignment: .topLeading) {
                // Opaque layers composited once, so overlaps don't mix colours.
                ZStack(alignment: .topLeading) {
                    Rectangle().fill(Band.hard.color)
                    discs(pivots, radius: Self.stretchRadius).fill(Band.stretch.color)
                    discs(pivots, radius: Self.easyRadius).fill(Band.easy.color)
                    if let fold = snapshot.fold {
                        Rectangle().fill(Band.hard.color)
                            .frame(width: fold.width, height: fold.height)
                            .offset(x: fold.minX, y: fold.minY)
                    }
                }
                .frame(width: size.width, height: size.height, alignment: .topLeading)
                .mask(alignment: .topLeading) {
                    Rectangle().frame(width: content.width, height: content.height).offset(x: content.minX)
                }
                .compositingGroup()
                .opacity(0.22)
                if let fold = snapshot.fold {
                    // The fold is hard to hit even where a thumb reaches it; outline it so it reads.
                    Rectangle()
                        .strokeBorder(Band.hard.color.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        .frame(width: fold.width, height: fold.height)
                        .offset(x: fold.minX, y: fold.minY)
                }
                legend
                    .padding(.leading, content.minX + 8)
                    .padding(.top, 8)
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func discs(_ pivots: [CGPoint], radius: CGFloat) -> Path {
        var path = Path()
        for pivot in pivots {
            path.addEllipse(in: CGRect(x: pivot.x - radius, y: pivot.y - radius, width: radius * 2, height: radius * 2))
        }
        return path
    }

    private var legend: some View {
        HStack(spacing: 8) {
            ForEach(Band.allCases, id: \.self) { band in
                HStack(spacing: 3) {
                    Circle().fill(band.color).frame(width: 7, height: 7)
                    Text(band.title)
                }
            }
            Text("· model, not measured").foregroundStyle(.white.opacity(0.7))
        }
        .font(.system(size: 10, weight: .medium))
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(.black.opacity(0.65), in: Capsule())
        .foregroundStyle(.white)
    }
}

/// Adds the global HUD and the banner. Apply on the root and inside every full-screen cover.
struct DuoChrome: ViewModifier {
    /// Screens that draw the reach overlay themselves (under their own controls) pass false.
    var includesReach = true
    @Environment(AppRouter.self) private var router
    @AppStorage(ReachOverlay.storageKey) private var showsReach = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if includesReach, showsReach { ReachOverlay() }
            }
            .overlay {
                if router.measure { HUDOverlay() }
            }
            .overlay(alignment: .top) {
                if let banner = router.banner {
                    Text(banner)
                        .font(.footnote.weight(.medium))
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .glassEffect(.regular, in: .rect(cornerRadius: 16))
                        .padding(.top, 8)
                        .padding(.horizontal)
                        .onTapGesture { router.banner = nil }
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: router.banner)
    }
}

extension View {
    func duoChrome(includesReach: Bool = true) -> some View { modifier(DuoChrome(includesReach: includesReach)) }
}

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

/// Adds the global HUD and the banner. Apply on the root and inside every full-screen cover.
struct DuoChrome: ViewModifier {
    @Environment(AppRouter.self) private var router

    func body(content: Content) -> some View {
        content
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
    func duoChrome() -> some View { modifier(DuoChrome()) }
}

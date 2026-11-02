import SwiftUI

enum OverlaysLab {
    static let options: [LabOption] = [
        LabOption("fold-aware", "Fold-aware overlay", .recommended,
                  summary: "The floating video steps aside from the fold and cameras; the controls sit to one side.",
                  pros: ["Nothing interactive lands in the curve", "Works in every pose"],
                  cons: ["A little extra work for the app"],
                  lookFor: "Book pose: drag the bubble to the middle. It jumps to one side.",
                  knobs: ["avoid": "on", "cluster": "avoid"]),
        LabOption("split-controls", "Controls split by the fold", .consider,
                  summary: "Play controls on one half, settings on the other.",
                  pros: ["Uses both halves", "Thumbs reach both groups in book pose"],
                  cons: ["Two groups to scan"],
                  lookFor: "Hold the device like a book: each thumb gets a group.",
                  knobs: ["avoid": "on", "cluster": "split"]),
        LabOption("unaware", "Fold-unaware", .avoid,
                  summary: "Floating video and controls placed as on a phone, ignoring the fold.",
                  pros: [],
                  cons: ["Centered controls sit right on the fold", "The bubble can cover the camera"],
                  lookFor: "Book pose: the control row is cut by the fold.",
                  knobs: ["avoid": "off", "cluster": "center", "bubble": "large"]),
    ]

    static let knobs: [KnobSpec] = [
        .toggle("avoid", "Bubble avoids reserved regions", default: true,
                note: "Query reservedRegions(kind: .division / .occlusion) and push the bubble off the fold and cameras. System containers do this for you; custom overlays don't.",
                facts: ["F-3a", "F-6b", "D11"]),
        KnobSpec("bubble", "Bubble size", options: [.init("small", "Small"), .init("large", "Large")], default: "small",
                 note: "A large bubble on the inner display is the case most likely to sit on the fold.",
                 facts: ["D8"]),
        KnobSpec("cluster", "Control cluster", options: [
            .init("center", "Centered"), .init("avoid", "Beside fold"), .init("split", "Split by fold"),
        ], note: "HIG: keep interactive elements out of the curve. Centered controls land right on the fold of the open device.",
        facts: ["F-6b"]),
    ]
}

struct OverlaysLabView: View {
    let state: KnobState
    @State private var corner = 3
    @State private var drag: CGSize = .zero

    private var bubbleSize: CGSize { state["bubble"] == "large" ? CGSize(width: 320, height: 200) : CGSize(width: 180, height: 110) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [.teal.opacity(0.35), .blue.opacity(0.25)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            RegionReader { size, folds, occlusions in
                ZStack(alignment: .topLeading) {
                    cluster(size: size, folds: folds)

                    bubble
                        .frame(width: bubbleSize.width, height: bubbleSize.height)
                        .position(bubbleCenter(size: size, folds: folds, occlusions: occlusions))
                        .offset(drag)
                        .gesture(
                            DragGesture()
                                .onChanged { drag = $0.translation }
                                .onEnded { value in
                                    let base = cornerCenter(corner, size: size)
                                    let end = CGPoint(x: base.x + value.translation.width, y: base.y + value.translation.height)
                                    corner = (end.y < size.height / 2 ? 0 : 2) + (end.x < size.width / 2 ? 0 : 1)
                                    withAnimation(.snappy) { drag = .zero }
                                }
                        )
                        .animation(.snappy, value: corner)
                }
            }
        }
    }

    private var bubble: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 16).fill(.black.gradient)
            Image(systemName: "video.fill").font(.title).foregroundStyle(.white).frame(maxWidth: .infinity, maxHeight: .infinity)
            Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.8)).padding(8)
        }
        .shadow(radius: 10)
    }

    /// Corners: 0 top-leading, 1 top-trailing, 2 bottom-leading, 3 bottom-trailing.
    private func cornerCenter(_ corner: Int, size: CGSize) -> CGPoint {
        let inset: CGFloat = 16
        let x = corner % 2 == 0 ? inset + bubbleSize.width / 2 : size.width - inset - bubbleSize.width / 2
        let y = corner < 2 ? inset + 90 + bubbleSize.height / 2 : size.height - inset - 70 - bubbleSize.height / 2
        return CGPoint(x: x, y: y)
    }

    private func bubbleCenter(size: CGSize, folds: [CGRect], occlusions: [CGRect]) -> CGPoint {
        var center = cornerCenter(corner, size: size)
        guard state.isOn("avoid") else { return center }
        let margin: CGFloat = 12
        for region in folds + occlusions {
            let frame = CGRect(x: center.x - bubbleSize.width / 2, y: center.y - bubbleSize.height / 2,
                               width: bubbleSize.width, height: bubbleSize.height)
            guard frame.intersects(region.insetBy(dx: -margin, dy: -margin)) else { continue }
            if region.height > region.width {
                // Vertical band (the fold): move to the side the bubble's center is on.
                center.x = center.x < region.midX
                    ? region.minX - margin - bubbleSize.width / 2
                    : region.maxX + margin + bubbleSize.width / 2
            } else {
                // Horizontal band (camera housing): move below it.
                center.y = region.maxY + margin + bubbleSize.height / 2
            }
        }
        return center
    }

    @ViewBuilder
    private func cluster(size: CGSize, folds: [CGRect]) -> some View {
        let y = size.height - 40
        let buttons = ["backward.fill", "play.fill", "forward.fill", "speaker.wave.2.fill", "captions.bubble.fill", "gearshape.fill"]
        switch (state["cluster"], folds.first) {
        case ("avoid", let fold?):
            controlRow(buttons).position(x: fold.minX / 2, y: y)
        case ("split", let fold?):
            controlRow(Array(buttons.prefix(3))).position(x: fold.minX / 2, y: y)
            controlRow(Array(buttons.suffix(3))).position(x: fold.maxX + (size.width - fold.maxX) / 2, y: y)
        default:
            controlRow(buttons).position(x: size.width / 2, y: y)
        }
    }

    private func controlRow(_ symbols: [String]) -> some View {
        HStack(spacing: 20) {
            ForEach(symbols, id: \.self) { Image(systemName: $0) }
        }
        .font(.title3)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .glassEffect(.regular.interactive(), in: .capsule)
        .fixedSize()
    }
}

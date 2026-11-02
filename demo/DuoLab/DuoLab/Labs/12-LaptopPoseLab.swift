import SwiftUI

enum LaptopPoseLab {
    static let options: [LabOption] = [
        LabOption("overlay", "Video up, controls down", .recommended,
                  summary: "Folded or flat, the controls float over the video. Half open on a table, the video moves to the top half and the full controls fill the bottom half.",
                  pros: ["The video stays fully visible from across the room", "Controls sit on the steady half, near your hand", "Same controls in every pose"],
                  cons: ["Two looks for the controls to design: floating and full"],
                  lookFor: "Turn on the simulated laptop pose: the video is wholly above the fold, every control is below it, nothing sits on the fold.",
                  knobs: ["layout": "overlay"], highlight: "simulatedPose"),
        LabOption("split", "Side by side only", .consider,
                  summary: "Video and controls side by side when there is room; the layout never splits top and bottom.",
                  pros: ["Good in book pose: one half each"],
                  cons: ["Ignores the laptop pose: the fold cuts across the video and the controls"],
                  lookFor: "Simulated laptop pose: the fold runs through both panes.",
                  knobs: ["layout": "split"], highlight: "simulatedPose"),
        LabOption("same", "Same layout everywhere", .consider,
                  summary: "Video on top, controls and list below, whatever the pose.",
                  pros: ["Simple and predictable", "Fine for lists and settings that don't need a special pose"],
                  cons: ["The fold lands wherever it lands, often on the controls"],
                  lookFor: "Book and laptop pose: what the fold crosses.",
                  knobs: ["layout": "same"], highlight: "simulatedPose"),
        LabOption("laptop-only", "Laptop layout drops controls", .avoid,
                  summary: "A special laptop layout: big video on top, only the up-next list below. Play, pause and the scrubber are gone.",
                  pros: ["Clean and minimal"],
                  cons: ["Lay the device flat on a table and you can no longer pause", "Breaks the rule of the same controls in every pose"],
                  lookFor: "Simulated laptop pose: try to pause.",
                  knobs: ["layout": "laptopOnly"], highlight: "simulatedPose"),
        LabOption("controls-top", "Controls on the top half", .avoid,
                  summary: "In laptop pose the controls go up and the video goes down.",
                  pros: [],
                  cons: ["The top half wobbles when you tap it", "Hard to reach", "The video sits flat on the table, hard to see"],
                  lookFor: "Simulated laptop pose: the video ends up on the half that lies flat.",
                  knobs: ["layout": "controlsTop"], highlight: "simulatedPose"),
    ]

    static let knobs: [KnobSpec] = [
        KnobSpec("layout", "Layout", options: [
            .init("overlay", "Arrangement, overlay"), .init("split", "Arrangement, split horizontal"),
            .init("same", "Same in every pose"), .init("laptopOnly", "Laptop-only, no controls"),
            .init("controlsTop", "Controls on top"),
        ], note: "Apple: in laptop pose put media in the top region and tappable controls in the bottom region. The overlay arrangement does this for you; the fold's direction is only visible as the shape of the division region (wide means laptop).",
        facts: ["F-3b", "F-6b", "F-6c", "D11"]),
        KnobSpec("controls", "Controls", options: [.init("full", "Full"), .init("minimal", "Minimal")],
                 note: "Full adds skip, captions, a problem report and the up-next list. Minimal is play and the scrubber.",
                 facts: []),
        KnobSpec("simulatedPose", "Simulated pose", options: [.init("off", "Real pose"), .init("laptop", "Laptop (simulated)")],
                 note: "The simulator's half-open pose folds top to bottom (book). Laptop fakes a fold across the middle and lays the screen out by hand, the way the overlay arrangement does on a device.",
                 facts: ["F-5a", "F-3a"]),
    ]
}

// MARK: - View

struct LaptopPoseLabView: View {
    let state: KnobState
    @Environment(\.isThumbnail) private var isThumbnail
    @State private var player = LaptopPlayer()
    @State private var showsAlert = false

    var body: some View {
        GeometryReader { proxy in
            // Thumbnails always show the laptop arrangement so the cards differ.
            let fake = state["simulatedPose"] == "laptop" || isThumbnail
                ? CGRect(x: 0, y: proxy.size.height / 2 - 14, width: proxy.size.width, height: 28) : nil
            RegionReader { size, folds, _ in
                content(size: size, fold: folds.first, simulated: fake != nil)
            }
            .environment(\.simulatedFold, fake)
            .overlay {
                if let fake { SimulatedFoldBand(frame: fake) }
            }
        }
        .background(.black)
        .environment(player)
        .environment(\.laptopControls, LaptopControlsConfig(full: state["controls"] == "full", onReport: { showsAlert = true }))
        .alert("Report a problem?", isPresented: $showsAlert) {
            Button("Report") {}
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("In laptop pose the system moves this alert to the top half.")
        }
        .task { await player.run() }
    }

    @ViewBuilder
    private func content(size: CGSize, fold: CGRect?, simulated: Bool) -> some View {
        let laptopFold = fold.flatMap { $0.width > $0.height ? $0 : nil }
        switch state["layout"] {
        case "split":
            if simulated {
                // What a horizontal-only split does flat; it never reacts to a wide fold.
                HStack(spacing: 0) {
                    LaptopMedia()
                    LaptopDeck(mode: .expanded).frame(width: size.width * 0.42)
                }
            } else {
                ArrangementView { LaptopDeck(mode: .expanded) } secondary: { LaptopMedia() }
                    .arrangementViewStyle(.split.axes(.horizontal))
            }
        case "same":
            SameEverywhere(size: size)
        case "laptopOnly":
            if let laptopFold {
                TopBottom(size: size, fold: laptopFold) {
                    LaptopMedia(large: true)
                } bottom: {
                    UpNextList(title: "Up next").background(.background)
                }
            } else {
                overlayArrangement(fold: fold)
            }
        case "controlsTop":
            if let laptopFold, simulated {
                TopBottom(size: size, fold: laptopFold) {
                    LaptopDeck(mode: .expanded)
                } bottom: {
                    LaptopMedia()
                }
            } else {
                overlayArrangement(fold: fold).overlayArrangementEdge(VerticalEdge.top)
            }
        default:
            if let laptopFold, simulated {
                // Drawn by hand: what the overlay arrangement does in a real laptop pose.
                TopBottom(size: size, fold: laptopFold) {
                    LaptopMedia()
                } bottom: {
                    LaptopDeck(mode: .expanded)
                }
            } else {
                overlayArrangement(fold: fold)
            }
        }
    }

    /// Flat or closed the controls float over the video; with a fold they get their own region.
    private func overlayArrangement(fold: CGRect?) -> some View {
        ArrangementView { LaptopDeck(mode: fold == nil ? .floating : .expanded) } secondary: { LaptopMedia() }
            .arrangementViewStyle(.overlay)
    }
}

/// Top region above the fold, bottom region below it; the fold itself stays empty.
private struct TopBottom<Top: View, Bottom: View>: View {
    let size: CGSize
    let fold: CGRect
    @ViewBuilder let top: Top
    @ViewBuilder let bottom: Bottom

    var body: some View {
        VStack(spacing: 0) {
            top.frame(height: max(0, fold.minY))
            Color.black.frame(height: fold.height)
            bottom.frame(height: max(0, size.height - fold.maxY))
        }
        .frame(width: size.width, height: size.height)
    }
}

/// One fixed layout in every pose: video, a row of controls, then the list.
private struct SameEverywhere: View {
    let size: CGSize

    var body: some View {
        VStack(spacing: 0) {
            LaptopMedia().frame(height: min(size.height * 0.45, size.width * 9 / 16))
            LaptopDeck(mode: .row)
            UpNextList(title: "Up next")
        }
        .background(.background)
    }
}

private struct SimulatedFoldBand: View {
    let frame: CGRect

    var body: some View {
        ZStack {
            Rectangle().fill(.gray.opacity(0.35))
            Text("SIMULATED FOLD")
                .font(.caption2.bold())
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(width: frame.width, height: frame.height)
        .position(x: frame.midX, y: frame.midY)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Player state

@MainActor
@Observable
final class LaptopPlayer {
    var isPlaying = true
    var progress = 0.32
    let length = 48.0 * 60

    func run() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(500))
            if isPlaying { progress = (progress + 0.5 / length).truncatingRemainder(dividingBy: 1) }
        }
    }

    func skip(_ seconds: Double) { progress = min(1, max(0, progress + seconds / length)) }

    var elapsedText: String { Self.time(progress * length) }
    var remainingText: String { "-" + Self.time((1 - progress) * length) }

    private static func time(_ seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

struct LaptopControlsConfig: Sendable {
    var full = true
    var onReport: @MainActor @Sendable () -> Void = {}
}

extension EnvironmentValues {
    @Entry var laptopControls = LaptopControlsConfig()
}

// MARK: - Pieces

private struct LaptopMedia: View {
    var large = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [.indigo, .purple, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack {
                HStack {
                    Label("LIVE", systemImage: "dot.radiowaves.left.and.right")
                        .font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.red, in: .capsule)
                    Spacer()
                    Text("Episode 12 · Blue hour").font(.caption.bold())
                }
                Spacer()
                Image(systemName: "mountain.2.fill").font(.system(size: large ? 96 : 64))
                Spacer()
            }
            .foregroundStyle(.white)
            .padding()
        }
        .clipped()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Video, live, Episode 12")
    }
}

/// The player controls: a floating bar over the video, a full deck in its own region,
/// or a plain row. On the 27.1 simulator `overlayArrangementZIndex` read 0 in every pose,
/// so the lab picks floating vs full from the division region instead.
private struct LaptopDeck: View {
    enum Mode { case floating, expanded, row }
    let mode: Mode
    @Environment(\.laptopControls) private var config
    @Environment(LaptopPlayer.self) private var player

    var body: some View {
        switch mode {
        case .row:
            VStack(spacing: 8) {
                transport
                scrubber
            }
            .padding()
            .background(.bar)
        case .expanded:
            deck
        case .floating:
            VStack {
                    Spacer()
                    VStack(spacing: 8) {
                        transport
                        scrubber
                    }
                    .padding()
                    .glassEffect(.regular, in: .rect(cornerRadius: 24))
                    .frame(maxWidth: 520)
                    .padding()
            }
        }
    }

    private var deck: some View {
        VStack(spacing: 12) {
            transport.padding(.top, 12)
            scrubber
            if config.full {
                HStack(spacing: 24) {
                    Button("Captions", systemImage: "captions.bubble") {}
                    Button("Speed", systemImage: "gauge.with.dots.needle.67percent") {}
                    Button("Report", systemImage: "exclamationmark.bubble") { config.onReport() }
                }
                .labelStyle(.iconOnly)
                .font(.title3)
                UpNextList(title: "Up next")
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }

    private var transport: some View {
        HStack(spacing: 28) {
            if config.full {
                Button("Back 10 seconds", systemImage: "gobackward.10") { player.skip(-10) }
            }
            Button(player.isPlaying ? "Pause" : "Play", systemImage: player.isPlaying ? "pause.fill" : "play.fill") {
                player.isPlaying.toggle()
            }
            .font(.largeTitle)
            if config.full {
                Button("Forward 10 seconds", systemImage: "goforward.10") { player.skip(10) }
                Button("Next", systemImage: "forward.end.fill") {}
            }
        }
        .labelStyle(.iconOnly)
        .font(.title2)
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    private var scrubber: some View {
        @Bindable var player = player
        return VStack(spacing: 2) {
            Slider(value: $player.progress, in: 0...1) { Text("Position") }
            HStack {
                Text(player.elapsedText)
                Spacer()
                Text(player.remainingText)
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: 560)
    }
}

private struct UpNextList: View {
    let title: String

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                Text(title).font(.headline)
                ForEach(0..<10, id: \.self) { index in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 8).fill(Placeholder.color(index).gradient)
                            .frame(width: 72, height: 44)
                            .overlay { Image(systemName: Placeholder.symbol(index)).foregroundStyle(.white) }
                        VStack(alignment: .leading) {
                            Text(Placeholder.name(index)).font(.subheadline.bold())
                            Text("\(20 + index * 3) min").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            .padding()
        }
        .background(.background)
    }
}

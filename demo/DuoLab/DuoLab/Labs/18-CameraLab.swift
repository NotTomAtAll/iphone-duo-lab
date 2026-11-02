import SwiftUI

enum CameraLab {
    static let options: [LabOption] = [
        LabOption("upright-preview-flat-controls", "Preview up, controls down", .recommended,
                  summary: "Half open on a table, the preview sits in the upright half and the shutter, modes and buttons fill the flat half. Closed, the controls float over the preview like a normal phone camera.",
                  pros: ["The preview faces you; your hand rests on the steady half", "Nothing sits on the fold", "Same buttons in every pose"],
                  cons: ["Two control layouts to design: floating and full"],
                  lookFor: "Turn on the simulated laptop pose: the preview is wholly above the fold, every button is below it. Book pose: preview on the left, controls on the right.",
                  highlight: "simulatedPose"),
        LabOption("book-side-controls", "Preview one side, controls the other", .recommended,
                  summary: "Open in book pose, the preview fills the left half and the controls run down the right edge, with a second shutter under the left thumb.",
                  pros: ["Either thumb can take the shot", "The preview keeps its shape", "The fold stays empty"],
                  cons: ["Two shutters to keep in step"],
                  lookFor: "Book pose: the controls sit near the right edge, a small shutter waits bottom left, nothing crosses the fold. Simulated laptop: the flat half splits into a left and a right cluster.",
                  knobs: ["layout": "book"], highlight: "simulatedPose"),
        LabOption("same-everywhere", "Phone layout, stretched", .consider,
                  summary: "The phone camera screen grown to fill the window: preview on top, one bar of controls along the bottom, whatever the pose.",
                  pros: ["Simple, and familiar from the phone", "Works in every pose"],
                  cons: ["Wastes the flat half in laptop pose: the fold cuts across the preview", "Open, the shutter lands near the fold"],
                  lookFor: "Simulated laptop pose: the fold runs through the preview. Open: where the shutter sits against the fold.",
                  knobs: ["layout": "same"], highlight: "simulatedPose"),
        LabOption("selfie-outer-preview", "Rear-camera selfie", .consider,
                  summary: "Turned around, the rear cameras face you and the outer display becomes your mirrored preview. The inner display says how to get there.",
                  pros: ["Selfies with the better cameras", "The outer display is already pointing at you"],
                  cons: ["People have to know the trick", "Needs its own layout for the outer display"],
                  lookFor: "Closed: the preview is mirrored and the note says which cameras are shooting. Open: the same controls plus a hint to turn the device around.",
                  knobs: ["layout": "selfie"], highlight: "simulatedPose"),
        LabOption("controls-over-preview", "Controls floating across the fold", .avoid,
                  summary: "A full-bleed preview with the controls floating over it, centred on the whole window.",
                  pros: ["The biggest preview"],
                  cons: ["Open, the shutter sits right on the fold", "Half open, the fold cuts through the preview", "Buttons cover the picture"],
                  lookFor: "Open or book pose: the shutter is on the fold. Simulated laptop: the fold crosses the preview.",
                  knobs: ["layout": "overlay"], highlight: "simulatedPose"),
    ]

    static let knobs: [KnobSpec] = [
        KnobSpec("layout", "Layout", options: [
            .init("upright", "Preview up, controls down"), .init("book", "Side controls, two shutters"),
            .init("same", "Phone layout everywhere"), .init("selfie", "Rear-camera selfie"),
            .init("overlay", "Floating across the fold"),
        ], note: "Apple: media at the top, tappable controls on a stable base at the bottom; keep controls clear of the camera areas while the camera runs; keep the same functions in every pose.",
        facts: []),
        KnobSpec("simulatedPose", "Simulated pose", options: [.init("off", "Real pose"), .init("laptop", "Laptop (simulated)")],
                 note: "The simulator's half-open pose folds top to bottom (book). Laptop fakes a fold across the middle and lays the screen out by hand.",
                 facts: []),
        KnobSpec("mode", "Mode", options: [.init("photo", "Photo"), .init("video", "Video"), .init("portrait", "Portrait")],
                 note: "Photo and portrait keep a 3:4 preview, video 9:16. The preview keeps its shape in every pose; only the space around it changes.",
                 facts: []),
    ]
}

// MARK: - View

struct CameraLabView: View {
    let state: KnobState
    @Environment(\.isThumbnail) private var isThumbnail
    @Environment(\.simulatedFold) private var inheritedFold
    @State private var rig = CameraRig()

    var body: some View {
        GeometryReader { proxy in
            FoldLocator { size, gutter, reported in
                RegionReader { _, folds, _ in
                    // A camera app knows its camera is about to run, so it treats the inactive
                    // camera regions as reserved too.
                    GeometryReader { local in
                        let cameras = local.reservedRegions(kind: .occlusion, options: .includeInactive).map(\.frame)
                        let laptop = folds.first { $0.width > $0.height }
                        let vertical = laptop == nil ? gutter : nil
                        let plan = CameraPlan.make(layout: state["layout"], mode: state["mode"], size: size,
                                                   vertical: vertical, laptop: laptop, occlusions: cameras)
                        CameraScreen(plan: plan, state: state, gutter: vertical, reported: reported,
                                     laptop: laptop, cameras: cameras)
                    }
                }
            }
            .environment(\.simulatedFold, stagedFold(proxy.size))
        }
        .background(.black)
        .environment(rig)
        .animation(.smooth(duration: 0.3), value: state["mode"])
        .animation(.smooth(duration: 0.3), value: state["simulatedPose"])
    }

    /// The fold the layout should see: the simulated laptop band, a per-option stand-in for
    /// thumbnails (so the cards differ), or whatever the parent passed.
    private func stagedFold(_ size: CGSize) -> CGRect? {
        let band = CGRect(x: 0, y: size.height / 2 - 14, width: size.width, height: 28)
        if state["simulatedPose"] == "laptop" { return band }
        guard isThumbnail else { return inheritedFold }
        switch state["layout"] {
        case "book", "overlay":
            return inheritedFold ?? CGRect(x: size.width / 2 - 14, y: 0, width: 28, height: size.height)
        case "selfie": return inheritedFold
        default: return band
        }
    }
}

// MARK: - Layout plan

/// Where the preview and each group of controls go, worked out from the window, the fold and the cameras.
private struct CameraPlan {
    enum Deck { case floating, bar, panel, column, deck, splitThumbs, selfie }

    var preview: CGRect
    var fill = false
    var mirrored = false
    var deck: Deck
    var controls: CGRect
    /// A second shutter under the other thumb.
    var spare: CGRect?
    var note: String?

    static let barHeight: CGFloat = 180

    static func make(layout: String, mode: String, size: CGSize, vertical: CGRect?, laptop: CGRect?,
                     occlusions: [CGRect]) -> CameraPlan {
        let full = CGRect(origin: .zero, size: size)
        var plan: CameraPlan
        if let laptop {
            let top = CGRect(x: 0, y: 0, width: size.width, height: max(0, laptop.minY))
            let bottom = CGRect(x: 0, y: laptop.maxY, width: size.width, height: max(0, size.height - laptop.maxY))
            switch layout {
            case "same": plan = phone(full, mode: mode)
            case "overlay": plan = floating(full, centredOn: full.midX)
            case "book": plan = CameraPlan(preview: fit(mode, in: top), deck: .splitThumbs, controls: bottom)
            case "selfie":
                plan = CameraPlan(preview: fit(mode, in: top), deck: .deck, controls: bottom,
                                  note: "Turn the device around to shoot a selfie with the rear cameras")
            default: plan = CameraPlan(preview: fit(mode, in: top), deck: .deck, controls: bottom)
            }
        } else if let fold = vertical {
            let left = CGRect(x: 0, y: 0, width: max(0, fold.minX), height: size.height)
            let right = CGRect(x: fold.maxX, y: 0, width: max(0, size.width - fold.maxX), height: size.height)
            switch layout {
            case "same": plan = phone(full, mode: mode)
            case "overlay": plan = floating(full, centredOn: fold.midX)
            case "book":
                plan = CameraPlan(preview: fit(mode, in: left), deck: .column, controls: right,
                                  spare: CGRect(x: left.minX + 20, y: left.maxY - 84, width: 64, height: 64))
            case "selfie":
                plan = CameraPlan(preview: fit(mode, in: left), deck: .panel, controls: right,
                                  note: "Turn the device around: the rear cameras face you and the outer display shows you")
            default: plan = CameraPlan(preview: fit(mode, in: left), deck: .panel, controls: right)
            }
        } else {
            switch layout {
            case "same", "book": plan = phone(full, mode: mode)
            case "selfie":
                var selfie = floating(full, centredOn: full.midX)
                selfie.deck = .selfie
                selfie.mirrored = true
                selfie.note = "Rear cameras · mirrored preview"
                plan = selfie
            case "overlay": plan = floating(full, centredOn: full.midX)
            default:
                // Closed: a normal phone camera, controls floating over the preview.
                plan = floating(full, centredOn: full.midX)
                plan.preview = fit(mode, in: full)
                plan.fill = false
            }
        }
        plan.controls = keepClear(plan.controls, of: occlusions)
        plan.spare = plan.spare.map { keepClear($0, of: occlusions) }
        return plan
    }

    /// Preview on top, one bar of controls below it.
    private static func phone(_ full: CGRect, mode: String) -> CameraPlan {
        let area = CGRect(x: full.minX, y: full.minY, width: full.width, height: max(0, full.height - barHeight))
        return CameraPlan(preview: area, fill: true, deck: .bar,
                          controls: CGRect(x: full.minX, y: area.maxY, width: full.width, height: barHeight))
    }

    /// Full-bleed preview with the controls floating over it, centred on `x`.
    private static func floating(_ full: CGRect, centredOn x: CGFloat) -> CameraPlan {
        let width = min(full.width - 24, 400)
        return CameraPlan(preview: full, fill: true, deck: .floating,
                          controls: CGRect(x: x - width / 2, y: full.maxY - barHeight - 8, width: width, height: barHeight))
    }

    /// The largest rect of the mode's aspect ratio that fits in `rect`, centred, never stretched.
    static func fit(_ mode: String, in rect: CGRect) -> CGRect {
        guard rect.width > 0, rect.height > 0 else { return rect }
        let tall: CGFloat = mode == "video" ? 9.0 / 16.0 : 3.0 / 4.0
        let ratio = rect.height >= rect.width ? tall : 1 / tall
        var size = CGSize(width: rect.width, height: rect.width / ratio)
        if size.height > rect.height { size = CGSize(width: rect.height * ratio, height: rect.height) }
        return CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height)
    }

    /// Trims `rect` away from every camera region it overlaps, keeping the largest remainder.
    static func keepClear(_ rect: CGRect, of occlusions: [CGRect]) -> CGRect {
        var result = rect
        for hole in occlusions where result.intersects(hole) {
            let candidates = [
                CGRect(x: result.minX, y: hole.maxY, width: result.width, height: result.maxY - hole.maxY),
                CGRect(x: result.minX, y: result.minY, width: result.width, height: hole.minY - result.minY),
                CGRect(x: hole.maxX, y: result.minY, width: result.maxX - hole.maxX, height: result.height),
                CGRect(x: result.minX, y: result.minY, width: hole.minX - result.minX, height: result.height),
            ].filter { $0.width > 0 && $0.height > 0 }
            result = candidates.max { $0.width * $0.height < $1.width * $1.height } ?? result
        }
        return result
    }
}

// MARK: - Screen

private struct CameraScreen: View {
    let plan: CameraPlan
    let state: KnobState
    let gutter: CGRect?
    let reported: Bool
    let laptop: CGRect?
    let cameras: [CGRect]
    @Environment(CameraRig.self) private var rig

    /// Just above floating controls, otherwise along the bottom of the preview.
    private var noteY: CGFloat {
        plan.controls.intersects(plan.preview) ? plan.controls.minY - 26 : plan.preview.maxY - 28
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Viewfinder(mode: state["mode"], mirrored: plan.mirrored != rig.front, fill: plan.fill)
                .place(plan.preview)
            if let note = plan.note {
                Label(note, systemImage: "arrow.triangle.2.circlepath.camera")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .glassEffect(.regular, in: .capsule)
                    .frame(maxWidth: plan.preview.width - 24)
                    .position(x: plan.preview.midX, y: noteY)
            }
            if let gutter { FoldGutter(reported: reported).place(gutter) }
            if let laptop { LaptopFold().place(laptop) }
            ForEach(cameras.indices, id: \.self) { index in
                CameraArea().place(cameras[index])
            }
            CameraDeck(style: plan.deck, state: state).place(plan.controls)
            if let spare = plan.spare {
                ShutterButton(mode: state["mode"], size: 56)
                    .glassEffect(.regular, in: .circle)
                    .position(x: spare.midX, y: spare.midY)
            }
        }
    }
}

private extension View {
    func place(_ rect: CGRect) -> some View {
        frame(width: max(0, rect.width), height: max(0, rect.height))
            .position(x: rect.midX, y: rect.midY)
    }
}

/// The laptop fold drawn across the window.
private struct LaptopFold: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.gray.opacity(0.35))
            Text("SIMULATED FOLD").font(.caption2.bold()).foregroundStyle(.white.opacity(0.8))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Outline of a camera region the system reports.
private struct CameraArea: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(.yellow.opacity(0.8), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            .overlay { Image(systemName: "camera.fill").font(.caption2).foregroundStyle(.yellow.opacity(0.8)) }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: - Camera state

@MainActor
@Observable
final class CameraRig {
    var shots = 0
    var flash = 0
    var front = false
    var zoom = 1
    var recording = false
    var blink = false

    static let zooms = ["0.5×", "1×", "2×"]

    func shoot(mode: String) {
        if mode == "video" {
            recording.toggle()
            if !recording { shots += 1 }
            return
        }
        shots += 1
        blink = true
        Task {
            try? await Task.sleep(for: .milliseconds(90))
            withAnimation(.easeOut(duration: 0.25)) { blink = false }
        }
    }
}

// MARK: - Pieces

/// A moving placeholder picture standing in for the camera feed.
private struct Viewfinder: View {
    let mode: String
    let mirrored: Bool
    let fill: Bool
    @Environment(\.isThumbnail) private var isThumbnail
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(CameraRig.self) private var rig

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: isThumbnail || reduceMotion)) { context in
            let t = isThumbnail ? 0 : context.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                let w = proxy.size.width, h = proxy.size.height
                ZStack {
                    LinearGradient(colors: [Color(hue: 0.58 + 0.04 * sin(t / 5), saturation: 0.55, brightness: 0.6),
                                            Color(hue: 0.08 + 0.03 * cos(t / 7), saturation: 0.6, brightness: 0.85)],
                                   startPoint: UnitPoint(x: 0.5 + 0.3 * cos(t / 4), y: 0),
                                   endPoint: UnitPoint(x: 0.5 - 0.3 * cos(t / 4), y: 1))
                    Circle().fill(.white.opacity(0.22))
                        .frame(width: min(w, h) * 0.6)
                        .blur(radius: 30)
                        .position(x: w * (0.5 + 0.22 * sin(t / 3)), y: h * (0.42 + 0.08 * cos(t / 2.5)))
                    Image(systemName: mode == "portrait" ? "person.crop.circle.fill" : "mountain.2.fill")
                        .font(.system(size: min(w, h) * (mode == "portrait" ? 0.38 : 0.3)))
                        .foregroundStyle(.white.opacity(0.85))
                        .blur(radius: mode == "portrait" ? 0 : 0.5)
                        .position(x: w / 2 + 6 * sin(t), y: h / 2 + 4 * cos(t * 0.8))
                    ThirdsGrid()
                    FocusSquare().frame(width: 72, height: 72).position(x: w * 0.5, y: h * 0.48)
                    if rig.recording {
                        Label("REC", systemImage: "record.circle")
                            .font(.caption.bold()).foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.red, in: .capsule)
                            .position(x: w / 2, y: h - 24)
                    }
                    if mode == "portrait" {
                        Text("DEPTH EFFECT").font(.caption2.bold()).foregroundStyle(.yellow)
                            .padding(4).background(.black.opacity(0.4), in: .rect(cornerRadius: 4))
                            .position(x: w / 2, y: h * 0.48 + 56)
                    }
                }
                .scaleEffect(x: mirrored ? -1 : 1)
            }
        }
        .overlay { Color.white.opacity(rig.blink ? 0.85 : 0).allowsHitTesting(false) }
        .clipShape(.rect(cornerRadius: fill ? 0 : 12))
        .accessibilityElement()
        .accessibilityLabel("Camera preview, placeholder")
    }
}

private struct ThirdsGrid: View {
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                for i in 1...2 {
                    let x = proxy.size.width * CGFloat(i) / 3, y = proxy.size.height * CGFloat(i) / 3
                    path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: proxy.size.height))
                    path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                }
            }
            .stroke(.white.opacity(0.25), lineWidth: 0.5)
        }
    }
}

private struct FocusSquare: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 4).strokeBorder(.yellow, lineWidth: 1.5)
    }
}

/// The camera's controls, arranged for the space they were given.
private struct CameraDeck: View {
    let style: CameraPlan.Deck
    let state: KnobState
    @Environment(CameraRig.self) private var rig

    var body: some View {
        let mode = state["mode"]
        switch style {
        case .floating:
            VStack(spacing: 12) {
                HStack { FlashButton(); Spacer(); ModeStrip(state: state, axis: .horizontal); Spacer(); ZoomButton() }
                HStack { LastShot(); Spacer(); ShutterButton(mode: mode); Spacer(); FlipButton() }
            }
            .padding(16)
            .glassEffect(.regular, in: .rect(cornerRadius: 32))
            .frame(maxHeight: .infinity, alignment: .bottom)
        case .bar:
            VStack(spacing: 12) {
                HStack { FlashButton(); Spacer(); ModeStrip(state: state, axis: .horizontal); Spacer(); ZoomButton() }
                    .frame(maxWidth: 420)
                HStack { LastShot(); Spacer(); ShutterButton(mode: mode); Spacer(); FlipButton() }
                    .frame(maxWidth: 420)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
        case .selfie:
            VStack(spacing: 12) {
                HStack { FlashButton(); Spacer(); ModeStrip(state: state, axis: .horizontal); Spacer(); ZoomButton() }
                HStack { LastShot(); Spacer(); ShutterButton(mode: mode, size: 84); Spacer(); TimerButton() }
            }
            .padding(16)
            .glassEffect(.regular, in: .rect(cornerRadius: 32))
            .frame(maxHeight: .infinity, alignment: .bottom)
        case .panel:
            VStack(spacing: 28) {
                HStack { FlashButton(); Spacer(); ZoomButton() }
                Spacer(minLength: 0)
                ModeStrip(state: state, axis: .horizontal)
                ShutterButton(mode: mode, size: 84)
                HStack { LastShot(); Spacer(); FlipButton() }.frame(maxWidth: 280)
                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
        case .column:
            HStack {
                Spacer(minLength: 0)
                VStack(spacing: 24) {
                    FlashButton()
                    ZoomButton()
                    Spacer(minLength: 0)
                    ModeStrip(state: state, axis: .vertical)
                    ShutterButton(mode: mode, size: 84)
                    LastShot()
                    FlipButton()
                }
                .padding(.vertical, 24)
                .padding(.trailing, 28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
        case .deck:
            VStack(spacing: 16) {
                HStack { FlashButton(); Spacer(); ZoomButton() }.frame(maxWidth: 520)
                ModeStrip(state: state, axis: .horizontal)
                HStack { LastShot(); Spacer(); ShutterButton(mode: mode, size: 84); Spacer(); FlipButton() }
                    .frame(maxWidth: 420)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
        case .splitThumbs:
            HStack(alignment: .center) {
                VStack(spacing: 18) {
                    ModeStrip(state: state, axis: .horizontal)
                    HStack(spacing: 20) { FlashButton(); ZoomButton(); LastShot() }
                }
                Spacer()
                HStack(spacing: 24) { FlipButton(); ShutterButton(mode: mode, size: 84) }
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
        }
    }
}

private struct ModeStrip: View {
    let state: KnobState
    let axis: Axis

    private let modes = [("photo", "Photo"), ("video", "Video"), ("portrait", "Portrait")]

    var body: some View {
        let layout = axis == .horizontal ? AnyLayout(HStackLayout(spacing: 20)) : AnyLayout(VStackLayout(spacing: 14))
        layout {
            ForEach(modes, id: \.0) { value, title in
                Button(title.uppercased()) { state["mode"] = value }
                    .font(.caption.bold())
                    .foregroundStyle(state["mode"] == value ? .yellow : .white)
                    .accessibilityAddTraits(state["mode"] == value ? .isSelected : [])
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mode")
    }
}

private struct ShutterButton: View {
    let mode: String
    var size: CGFloat = 72
    @Environment(CameraRig.self) private var rig

    var body: some View {
        Button { rig.shoot(mode: mode) } label: {
            ZStack {
                Circle().strokeBorder(.white, lineWidth: size * 0.06)
                if mode == "video" {
                    RoundedRectangle(cornerRadius: rig.recording ? size * 0.08 : size * 0.4)
                        .fill(.red)
                        .frame(width: size * (rig.recording ? 0.4 : 0.78), height: size * (rig.recording ? 0.4 : 0.78))
                } else {
                    Circle().fill(.white).padding(size * 0.11)
                }
            }
            .frame(width: size, height: size)
            .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode == "video" ? (rig.recording ? "Stop recording" : "Record") : "Take photo")
    }
}

private struct RoundIcon: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(title, systemImage: symbol, action: action)
            .labelStyle(.iconOnly)
            .font(.title3)
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .background(.white.opacity(0.15), in: .circle)
            .buttonStyle(.plain)
    }
}

private struct FlipButton: View {
    @Environment(CameraRig.self) private var rig

    var body: some View {
        RoundIcon(title: rig.front ? "Use back camera" : "Use front camera",
                  symbol: "arrow.triangle.2.circlepath.camera") { rig.front.toggle() }
    }
}

private struct FlashButton: View {
    @Environment(CameraRig.self) private var rig

    var body: some View {
        let symbols = ["bolt.slash.fill", "bolt.badge.automatic.fill", "bolt.fill"]
        let names = ["Flash off", "Flash auto", "Flash on"]
        RoundIcon(title: names[rig.flash], symbol: symbols[rig.flash]) { rig.flash = (rig.flash + 1) % 3 }
    }
}

private struct ZoomButton: View {
    @Environment(CameraRig.self) private var rig

    var body: some View {
        Button(CameraRig.zooms[rig.zoom]) { rig.zoom = (rig.zoom + 1) % CameraRig.zooms.count }
            .font(.caption.bold())
            .foregroundStyle(.yellow)
            .frame(width: 48, height: 48)
            .background(.white.opacity(0.15), in: .circle)
            .buttonStyle(.plain)
            .accessibilityLabel("Zoom \(CameraRig.zooms[rig.zoom])")
    }
}

private struct TimerButton: View {
    @State private var on = false

    var body: some View {
        RoundIcon(title: on ? "Timer 3 seconds" : "Timer off", symbol: on ? "timer.circle.fill" : "timer") { on.toggle() }
    }
}

private struct LastShot: View {
    @Environment(CameraRig.self) private var rig

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Placeholder.color(rig.shots + 3).gradient)
            .overlay { Image(systemName: Placeholder.symbol(rig.shots)).foregroundStyle(.white) }
            .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.6), lineWidth: 1) }
            .frame(width: 48, height: 48)
            .accessibilityElement()
            .accessibilityLabel(rig.shots == 0 ? "Last photo, none yet" : "Last photo, \(rig.shots) taken")
    }
}

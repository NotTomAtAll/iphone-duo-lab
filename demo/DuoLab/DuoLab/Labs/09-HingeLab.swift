import SwiftUI

enum HingeLab {
    static let options: [LabOption] = [
        LabOption("book", "Book pages", .effect,
                  summary: "Two pages open with the hinge.",
                  pros: ["Makes the pose feel physical"], cons: ["Decorative only"],
                  lookFor: "Move between book and fully open."),
        LabOption("lamp", "Lamp light", .effect,
                  summary: "Light grows as the device opens.",
                  pros: ["Subtle"], cons: ["Decorative only"],
                  lookFor: "Brightness follows the angle.",
                  knobs: ["effect": "lamp"]),
        LabOption("tilt", "Card tilt", .effect,
                  summary: "A card tilts back as the device closes.",
                  pros: ["Good for a cover or hero image"], cons: ["Decorative only"],
                  lookFor: "The card's tilt in book pose.",
                  knobs: ["effect": "tilt"]),
        // B9: hinge effect hygiene.
        LabOption("effect-only", "Angle drives the effect only", .recommended,
                  summary: "A real screen: the angle moves a decorative header, while the list's columns come from the space the screen has.",
                  pros: ["The effect follows the hand with no lag", "Layout never flickers, and is right on any device"],
                  cons: ["The angle can do nothing structural"],
                  lookFor: "Move the slider through 90\u{00B0}: the header moves, the columns don't. Folded you get one column, open you get two.",
                  knobs: ["layout": "space", "source": "slider"], highlight: "layout"),
        LabOption("layout-from-angle", "Angle decides the layout", .avoid,
                  summary: "The same screen, but the number of columns switches when the angle crosses 90\u{00B0}.",
                  pros: ["Looks clever in a demo"],
                  cons: ["Flickers back and forth when the hand rests near the switch point",
                         "Wrong on hardware with a different range, and when no angle is reported (the outer display shows two columns)",
                         "The width hasn't changed, so the new layout doesn't fit any better"],
                  lookFor: "Wiggle the slider around 90\u{00B0}: the whole list re-flows on every crossing.",
                  knobs: ["layout": "angle", "source": "slider"], highlight: "layout"),
        LabOption("haptic", "Light tap at each pose", .consider,
                  summary: "A light haptic tap, with no sound, when the device reaches closed, part open or fully open. Never on every degree.",
                  pros: ["Confirms the pose without looking", "Fires three times per fold at most"],
                  cons: ["Easy to overdo; leave it out if the pose change does nothing in the app", "The simulator has no haptics: watch the tick mark instead"],
                  lookFor: "Cross a pose boundary: the tick mark flashes once (and the device taps once).",
                  knobs: ["haptic": "on", "source": "slider"], highlight: "haptic"),
        LabOption("reduce-motion", "With Reduce Motion", .system,
                  summary: "With Reduce Motion on, the effect stops following the angle and only cross-fades between its closed, part-open and open states.",
                  pros: ["No continuous movement for people who asked for less", "The state is still shown"],
                  cons: ["Has to be designed: three still frames instead of one motion"],
                  lookFor: "Move the slider: nothing turns; the picture changes in three steps with a fade.",
                  knobs: ["motion": "reduced", "source": "slider"], highlight: "motion"),
    ]

    static let knobs: [KnobSpec] = [
        KnobSpec("effect", "Effect", options: [.init("book", "Book pages"), .init("lamp", "Lamp light"), .init("tilt", "Card tilt")],
                 note: "Apple: use the hinge for effects, not layout. Layout comes from size classes and reserved regions.",
                 facts: ["F-3d", "D11"]),
        KnobSpec("source", "Angle source", options: [.init("hinge", "Hinge"), .init("slider", "Slider")],
                 note: "The simulator changes pose by hand through its fold control (Option-drag for any angle). The slider fakes the angle for quick checks.",
                 facts: ["F-5a", "F-5b"]),
        KnobSpec("layout", "Screen", options: [.init("none", "Effect alone"), .init("space", "Columns from space"), .init("angle", "Columns from angle")],
                 note: "Puts the effect on a screen with a list. Columns should come from the width the screen has, never from the angle.",
                 facts: ["F-3d", "D11"]),
        .toggle("haptic", "Tap at each pose",
                note: "One light haptic when the hinge status changes (closed, part open, fully open). Not on every degree.",
                facts: ["F-3d"]),
        KnobSpec("motion", "Motion", options: [.init("full", "Full"), .init("reduced", "Reduced")],
                 note: "Reduced shows what the effect becomes with Reduce Motion on. The system setting also switches it.",
                 facts: ["F-3d"]),
    ]
}

/// Hinge status buckets used for the settle, the haptic and Reduce Motion.
private enum HingePose: String {
    case closed, partiallyOpen = "part open", fullyOpen = "fully open"

    init(angle: Double) {
        self = angle < 5 ? .closed : angle > 175 ? .fullyOpen : .partiallyOpen
    }

    /// The effect's progress in each still frame.
    var stillProgress: Double {
        switch self {
        case .closed: 0
        case .partiallyOpen: 0.5
        case .fullyOpen: 1
        }
    }
}

struct HingeLabView: View {
    let state: KnobState
    @State private var reading = HingeReading.unknown
    @State private var sliderAngle: Double = 120
    @State private var ticks = 0
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    /// Optional: thumbnails render this view in a hidden window without the router.
    @Environment(AppRouter.self) private var router: AppRouter?

    /// Quantised to 1° so sensor noise doesn't redraw the effect for nothing.
    private var angle: Double {
        (state["source"] == "slider" ? sliderAngle : (reading.angle ?? 180)).rounded()
    }

    private var pose: HingePose { HingePose(angle: angle) }
    private var reduced: Bool { state["motion"] == "reduced" || systemReduceMotion }

    var body: some View {
        Group {
            if state["layout"] == "none" {
                effectStage
            } else {
                HingeScreen(layoutFromAngle: state["layout"] == "angle", angle: angle) {
                    effect.frame(maxWidth: 340).frame(height: 130).padding(14).environment(\.colorScheme, .dark)
                } controls: {
                    readout(compact: true)
                    sourceControl
                }
            }
        }
        .foregroundStyle(state["layout"] == "none" ? Color.white : Color.primary)
        // ‹ › re-creates this view and onHingeChange only reports changes: start from the last
        // reading the app saw, not from "waiting".
        .onAppear { if let last = router?.hinge, last != .unknown { reading = last } }
        .onHingeChange { _, new in
            // No withAnimation: the effect tracks the hand directly.
            reading = HingeReading(new)
        }
        .onChange(of: pose) { ticks += 1 }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: pose) { _, _ in state.isOn("haptic") }
    }

    private var effectStage: some View {
        VStack(spacing: 24) {
            readout(compact: false)
            effect.frame(maxWidth: 520, maxHeight: 340)
            sourceControl
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.08 + 0.12 * angle / 180).ignoresSafeArea())
    }

    private func readout(compact: Bool) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                Text(String(format: "%.0f°", angle))
                    .font(.system(size: compact ? 34 : 56, weight: .bold, design: .rounded)).monospacedDigit()
                if state.isOn("haptic") {
                    Image(systemName: "hand.tap.fill")
                        .font(compact ? .title3 : .title)
                        .foregroundStyle(.yellow)
                        .keyframeAnimator(initialValue: 0.25, trigger: ticks) { view, opacity in
                            view.opacity(opacity)
                        } keyframes: { _ in
                            LinearKeyframe(1, duration: 0.05)
                            LinearKeyframe(1, duration: 0.25)
                            LinearKeyframe(0.25, duration: 0.3)
                        }
                        .accessibilityLabel("Haptic tick")
                }
            }
            Text(statusText).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var statusText: String {
        let source = state["source"] == "slider" ? "slider" : "hinge: \(reading.status)"
        return "\(source) · \(pose.rawValue)" + (reduced ? " · reduce motion" : "")
    }

    @ViewBuilder
    private var sourceControl: some View {
        if state["source"] == "slider" {
            Slider(value: $sliderAngle, in: 0...180) { Text("Angle") }
                .frame(maxWidth: 420)
        } else if reading.angle == nil {
            LookFor(text: "No angle yet. Use the simulator’s fold control, or switch the source to Slider.")
        }
    }

    @ViewBuilder
    private var effect: some View {
        if reduced {
            // Reduce Motion: three still frames, swapped with a cross-fade, no continuous movement.
            EffectDrawing(kind: state["effect"], progress: pose.stillProgress)
                .id(pose)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.35), value: pose)
        } else {
            EffectDrawing(kind: state["effect"], progress: angle / 180)
                // Only the status change gets a short settle; the angle itself is never animated.
                .animation(.snappy, value: pose)
        }
    }
}

/// The three decorative effects, drawn for a progress from 0 (closed) to 1 (fully open).
private struct EffectDrawing: View {
    let kind: String
    let progress: Double

    var body: some View {
        // Floor at 0.3 so the effect stays readable on the closed outer display (0°).
        let t = 0.3 + 0.7 * progress
        switch kind {
        case "lamp":
            ZStack {
                RadialGradient(colors: [.yellow.opacity(0.9 * t), .orange.opacity(0.3 * t), .clear],
                               center: .top, startRadius: 10, endRadius: 320)
                Image(systemName: "lamp.desk.fill").font(.system(size: 90)).foregroundStyle(.yellow.opacity(0.4 + 0.6 * t))
            }
        case "tilt":
            // The near edge of a tilted card projects wider than its frame: scaled down so it
            // stays inside the frame at every angle.
            Tile(index: 7)
                .rotation3DEffect(.degrees((1 - t) * 60), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                .scaleEffect(0.74)
                .shadow(radius: 20 * t)
        default:
            // Pages swung toward the viewer project taller than their frame: scaled down so they
            // never reach the readout above.
            HStack(spacing: 0) {
                page(index: 1).rotation3DEffect(.degrees((1 - t) * 80), axis: (x: 0, y: 1, z: 0), anchor: .trailing, perspective: 0.5)
                page(index: 2).rotation3DEffect(.degrees(-(1 - t) * 80), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.5)
            }
            .scaleEffect(0.8)
        }
    }

    private func page(index: Int) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(.white)
            .overlay(alignment: .topLeading) {
                Text(Placeholder.paragraphs[index]).font(.caption).foregroundStyle(.black.opacity(0.7)).padding()
            }
    }
}

/// A plain screen: decorative header, controls, and a list whose columns come from width or angle.
private struct HingeScreen<Header: View, Controls: View>: View {
    let layoutFromAngle: Bool
    let angle: Double
    @ViewBuilder let header: Header
    @ViewBuilder let controls: Controls

    var body: some View {
        GeometryReader { proxy in
            let columns = layoutFromAngle ? (angle >= 90 ? 2 : 1) : (proxy.size.width >= 700 ? 2 : 1)
            ScrollView {
                VStack(spacing: 16) {
                    header
                        .frame(maxWidth: .infinity)
                        .background(Color(white: 0.1), in: RoundedRectangle(cornerRadius: 16))
                    VStack(spacing: 8) { controls }
                    Text(layoutFromAngle
                         ? "\(columns) column\(columns == 1 ? "" : "s"), because the angle is \(angle >= 90 ? "at least" : "under") 90\u{00B0}"
                         : "\(columns) column\(columns == 1 ? "" : "s"), from the \(Int(proxy.size.width)) pt the screen has")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(layoutFromAngle ? .red : .green)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columns), spacing: 12) {
                        ForEach(0..<12, id: \.self) { index in
                            HStack(spacing: 12) {
                                Tile(index: index, showsCaption: false).frame(width: 56, height: 56)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(Placeholder.name(index)).font(.headline)
                                    Text(Placeholder.sentence).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(10)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color(.systemBackground))
    }
}

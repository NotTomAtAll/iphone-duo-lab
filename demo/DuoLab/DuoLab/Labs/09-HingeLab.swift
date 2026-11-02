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
    ]

    static let knobs: [KnobSpec] = [
        KnobSpec("effect", "Effect", options: [.init("book", "Book pages"), .init("lamp", "Lamp light"), .init("tilt", "Card tilt")],
                 note: "Apple: use the hinge for effects, not layout. Layout comes from size classes and reserved regions.",
                 facts: ["F-3d", "D11"]),
        KnobSpec("source", "Angle source", options: [.init("hinge", "Hinge"), .init("slider", "Slider")],
                 note: "The simulator only changes pose by hand in Device Hub (Option-drag for any angle). The slider fakes the angle for quick checks.",
                 facts: ["F-5a", "F-5b"]),
    ]
}

struct HingeLabView: View {
    let state: KnobState
    @State private var reading = HingeReading.unknown
    @State private var sliderAngle: Double = 120

    private var angle: Double {
        state["source"] == "slider" ? sliderAngle : (reading.angle ?? 180)
    }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 4) {
                Text(String(format: "%.0f°", angle)).font(.system(size: 56, weight: .bold, design: .rounded)).monospacedDigit()
                Text(state["source"] == "slider" ? "slider" : "hinge: \(reading.status)")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            effect
                .frame(maxWidth: 520, maxHeight: 340)
            if state["source"] == "slider" {
                Slider(value: $sliderAngle, in: 0...180) { Text("Angle") }
                    .frame(maxWidth: 420)
            } else if reading.angle == nil {
                LookFor(text: "No angle yet. Change pose in Device Hub, or switch the source to Slider.")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.08 + 0.12 * angle / 180).ignoresSafeArea())
        .foregroundStyle(.white)
        .onHingeChange { _, new in
            withAnimation(.smooth) { reading = HingeReading(new) }
        }
    }

    @ViewBuilder
    private var effect: some View {
        // Floor at 0.3 so the effect stays readable on the closed outer display (0°).
        let t = 0.3 + 0.7 * angle / 180
        switch state["effect"] {
        case "lamp":
            ZStack {
                RadialGradient(colors: [.yellow.opacity(0.9 * t), .orange.opacity(0.3 * t), .clear],
                               center: .top, startRadius: 10, endRadius: 320)
                Image(systemName: "lamp.desk.fill").font(.system(size: 90)).foregroundStyle(.yellow.opacity(0.4 + 0.6 * t))
            }
        case "tilt":
            Tile(index: 7)
                .rotation3DEffect(.degrees((1 - t) * 60), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                .shadow(radius: 20 * t)
        default:
            HStack(spacing: 0) {
                page(index: 1).rotation3DEffect(.degrees((1 - t) * 80), axis: (x: 0, y: 1, z: 0), anchor: .trailing, perspective: 0.5)
                page(index: 2).rotation3DEffect(.degrees(-(1 - t) * 80), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.5)
            }
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

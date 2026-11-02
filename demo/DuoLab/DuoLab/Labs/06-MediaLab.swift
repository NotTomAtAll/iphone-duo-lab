import SwiftUI

enum MediaLab {
    static let options: [LabOption] = [
        LabOption("arrangement-split", "Split around the fold", .recommended,
                  summary: "Video on one side of the fold, chat on the other. Folded, chat sits under the video.",
                  pros: ["The fold never cuts the video", "Stacks on the outer display without extra code"],
                  cons: ["Needs iOS 27.1 or later"],
                  lookFor: "Book pose: the split lands exactly on the fold."),
        LabOption("arrangement-overlay", "Panel over video", .consider,
                  summary: "When the device is flat, chat floats over the video.",
                  pros: ["Video keeps the full width when the device is flat"],
                  cons: ["The panel covers part of the video"],
                  lookFor: "Compare fully open with book pose.",
                  knobs: ["arrangement": "overlay"]),
        LabOption("fixed-panel", "Fixed side panel", .consider,
                  summary: "A chat column of fixed width beside the video.",
                  pros: ["Works on any OS version"],
                  cons: ["Ignores the fold", "Squeezes the video on the outer display"],
                  lookFor: "Fold: the video becomes a sliver.",
                  knobs: ["arrangement": "hstack"]),
        LabOption("full-bleed", "Full-bleed video", .consider,
                  summary: "Video runs edge to edge, under the clock and cameras.",
                  pros: ["Immersive edge to edge"],
                  cons: ["Buttons on the video must stay clear of the clock and cameras"],
                  lookFor: "The video under the rail; the LIVE badge still inside.",
                  knobs: ["video": "ignore"]),
        LabOption("sheet", "Panel in a sheet", .avoid,
                  summary: "Video only; chat opens in a separate sheet, as on a phone.",
                  pros: ["Same as the phone"],
                  cons: ["Wastes the open display", "Chat hides the video"],
                  lookFor: "Open the device: one video, no panel.",
                  knobs: ["arrangement": "stack"]),
    ]

    static let knobs: [KnobSpec] = [
        KnobSpec("arrangement", "Arrangement", options: [
            .init("split", "ArrangementView .split"), .init("overlay", "ArrangementView .overlay"),
            .init("hstack", "Plain HStack"), .init("stack", "Video only + sheet"),
        ], note: "ArrangementView splits along the fold when there is a division and stacks or overlays when there isn't. HStack is the same layout with no fold awareness.",
        facts: ["F-3b", "D11"]),
        KnobSpec("video", "Video safe area", options: [.init("respect", "Respect"), .init("ignore", "Ignore")],
                 note: "Full-bleed video under the rail and cameras looks good; controls on top of it must not follow it out of the safe area.",
                 facts: ["T-19", "M-1"]),
        KnobSpec("panel", "Side panel", options: [.init("chat", "Chat"), .init("details", "Details")],
                 note: "Live chat or episode details: either can sit beside the video on the inner display.",
                 facts: []),
    ]
}

struct MediaLabView: View {
    let state: KnobState
    @State private var showsPanelSheet = false

    var body: some View {
        Group {
            switch state["arrangement"] {
            case "split":
                ArrangementView { video } secondary: { panel }
                    .arrangementViewStyle(.split)
            case "overlay":
                ArrangementView { video } secondary: { panel }
                    .arrangementViewStyle(.overlay)
            case "hstack":
                HStack(spacing: 0) {
                    video
                    panel.frame(width: 320)
                }
            default:
                video
                    .overlay(alignment: .bottomTrailing) {
                        Button("Panel", systemImage: "sidebar.right") { showsPanelSheet = true }
                            .buttonStyle(.glass)
                            .padding()
                    }
                    .sheet(isPresented: $showsPanelSheet) {
                        panel.presentationDetents([.medium, .large])
                    }
            }
        }
        .background(.black)
    }

    private var video: some View {
        VideoStandIn(ignoresSafeArea: state["video"] == "ignore")
    }

    @ViewBuilder
    private var panel: some View {
        if state["panel"] == "chat" { ChatPanel() } else { DetailsPanel() }
    }
}

private struct VideoStandIn: View {
    let ignoresSafeArea: Bool

    var body: some View {
        ZStack {
            Group {
                if ignoresSafeArea {
                    gradient.ignoresSafeArea()
                } else {
                    gradient
                }
            }
            VStack {
                HStack {
                    Label("LIVE", systemImage: "dot.radiowaves.left.and.right")
                        .font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.red, in: .capsule)
                    Spacer()
                    Text("1.2k watching").font(.caption)
                }
                Spacer()
                Image(systemName: "play.circle.fill").font(.system(size: 64))
                Spacer()
            }
            .foregroundStyle(.white)
            .padding()
        }
    }

    private var gradient: some View {
        LinearGradient(colors: [.indigo, .purple, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private struct ChatPanel: View {
    var body: some View {
        VStack(spacing: 0) {
            Text("Chat").font(.headline).padding()
            List(0..<30, id: \.self) { index in
                HStack(alignment: .top) {
                    Circle().fill(Placeholder.color(index)).frame(width: 26, height: 26)
                    VStack(alignment: .leading) {
                        Text("viewer\(index)").font(.caption.bold())
                        Text(Placeholder.sentence).font(.caption).lineLimit(2)
                    }
                }
            }
            .listStyle(.plain)
            HStack {
                Text("Say something…").foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "paperplane.fill")
            }
            .padding()
            .background(.bar)
        }
        .background(.background)
    }
}

private struct DetailsPanel: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Episode 12 · Blue hour").font(.title2.bold())
                Text("48 min · Placeholder studio").foregroundStyle(.secondary)
                ForEach(Placeholder.paragraphs, id: \.self) { Text($0) }
            }
            .padding()
        }
        .background(.background)
    }
}

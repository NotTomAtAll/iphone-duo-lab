import SwiftUI

/// What the device hands the app right now: window, safe area, hinge, reserved regions.
struct DeviceView: View {
    @State private var hinge = HingeReading.unknown
    @Environment(AppRouter.self) private var router
    @AppStorage(ReachOverlay.storageKey) private var showsReach = false

    var body: some View {
        @Bindable var router = router
        NavigationStack {
            EnvironmentProbe { snapshot in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Fold and unfold the device and watch these values change. They are read live; nothing here is cached.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: 640, alignment: .leading)
                        LazyVGrid(columns: evenColumns(for: snapshot.size.width - snapshot.safeArea.leading - snapshot.safeArea.trailing - 40,
                                                       minimum: 320, spacing: 20),
                                  alignment: .leading, spacing: 20) {
                            windowCard(snapshot)
                            safeAreaCard(snapshot)
                            hingeCard
                            regionsCard(snapshot)
                        }
                        Toggle(isOn: $router.measure) {
                            Label("Show the measure overlay everywhere", systemImage: "ruler")
                        }
                        .padding(16)
                        .card()
                        .frame(maxWidth: 520)
                        reachCard(snapshot)
                            .frame(maxWidth: 520)
                    }
                    .padding(20)
                }
                .safeAreaPadding(.init(top: snapshot.safeArea.top, leading: snapshot.safeArea.leading,
                                       bottom: snapshot.safeArea.bottom, trailing: snapshot.safeArea.trailing))
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("Device")
        }
        .onHingeChange { _, new in withAnimation(.smooth) { hinge = HingeReading(new) } }
    }

    private func windowCard(_ s: EnvironmentSnapshot) -> some View {
        InfoCard(title: "Window", symbol: "macwindow") {
            Text("\(Int(s.size.width)) × \(Int(s.size.height))")
                .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
            + Text(" pt").font(.title3).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Tag(text: "Width \(EnvironmentSnapshot.name(s.horizontal))")
                Tag(text: "Height \(EnvironmentSnapshot.name(s.vertical))")
            }
            Text(s.horizontal == .regular ? "Inner display: an iPad-like regular environment." : "Outer display: behaves like any iPhone.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func safeAreaCard(_ s: EnvironmentSnapshot) -> some View {
        InfoCard(title: "Safe area of this screen", symbol: "rectangle.dashed") {
            SafeAreaDiagram(insets: s.safeArea, size: s.size)
                .frame(height: 150)
            Text("Includes this screen\u{2019}s navigation bar. The window itself has 0 on top; the status bar and cameras sit in the 84 pt trailing rail. Pad each edge by its own inset.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var hingeCard: some View {
        InfoCard(title: "Hinge", symbol: "book.pages") {
            HStack(alignment: .center, spacing: 18) {
                HingeGauge(angle: hinge.angle ?? 0)
                    .frame(width: 92, height: 92)
                VStack(alignment: .leading, spacing: 4) {
                    Text(hinge.angle.map { String(format: "%.0f°", $0) } ?? "—")
                        .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                    Text(hinge.status.capitalized).foregroundStyle(.secondary)
                }
            }
            Text("For effects only. Layout should never depend on the angle.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func reachCard(_ s: EnvironmentSnapshot) -> some View {
        InfoCard(title: "Reach", symbol: "hand.point.up.left") {
            Toggle("Show thumb reach zones everywhere", isOn: $showsReach)
            HStack(spacing: 8) {
                ForEach(ReachOverlay.Band.allCases, id: \.self) { band in
                    HStack(spacing: 4) {
                        Circle().fill(band.color).frame(width: 8, height: 8)
                        Text(band.title).font(.caption.weight(.medium))
                    }
                }
            }
            Text(s.horizontal == .regular
                 ? "Open: two thumbs, one from each bottom corner. The middle of the top edge is hard, and the fold is hard when the device is part open."
                 : "Folded: one right thumb from the bottom-trailing corner. The top-leading corner is hard.")
                .font(.footnote).foregroundStyle(.secondary)
            Text("Our model, not measured. Bands are fixed thumb radii (\(Int(ReachOverlay.easyRadius)) and \(Int(ReachOverlay.stretchRadius)) pt); the side column is left clear.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func regionsCard(_ s: EnvironmentSnapshot) -> some View {
        InfoCard(title: "Reserved regions", symbol: "square.dashed.inset.filled") {
            if s.regions.isEmpty {
                Text("None reported").foregroundStyle(.secondary)
            }
            ForEach(s.regions) { region in
                HStack {
                    Circle().fill(region.kind == "division" ? Color.red : Color.orange).frame(width: 8, height: 8)
                    Text(region.kind == "division" ? "Fold" : "Camera / sensor").font(.subheadline.weight(.medium))
                    if !region.isActive { Tag(text: "inactive") }
                    Spacer()
                    Text("x \(Int(region.frame.minX))  w \(Int(region.frame.width))")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            Text("The fold is active only when the device is partly open.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}

private struct InfoCard<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol).font(.headline)
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

private struct Tag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(.tertiarySystemFill), in: .capsule)
    }
}

/// The window drawn to scale with each inset labeled on its edge.
private struct SafeAreaDiagram: View {
    let insets: EdgeInsets
    let size: CGSize

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / max(size.width, 1), proxy.size.height / max(size.height, 1))
            let w = size.width * scale, h = size.height * scale
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.18))
                Rectangle()
                    .fill(Color(.systemBackground))
                    .overlay(Rectangle().strokeBorder(.green, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])))
                    .frame(width: max(w - (insets.leading + insets.trailing) * scale, 0),
                           height: max(h - (insets.top + insets.bottom) * scale, 0))
                    .offset(x: insets.leading * scale, y: insets.top * scale)
                label(insets.top).position(x: w / 2, y: max(insets.top * scale / 2, 8))
                label(insets.bottom).position(x: w / 2, y: h - max(insets.bottom * scale / 2, 8))
                label(insets.leading).position(x: max(insets.leading * scale / 2, 10), y: h / 2)
                label(insets.trailing).position(x: w - max(insets.trailing * scale / 2, 10), y: h / 2)
            }
            .frame(width: w, height: h)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func label(_ value: CGFloat) -> some View {
        Text("\(Int(value))").font(.caption2.weight(.bold).monospacedDigit())
    }
}

private struct HingeGauge: View {
    let angle: Double

    var body: some View {
        ZStack {
            Circle().trim(from: 0.5, to: 1).stroke(Color(.tertiarySystemFill), style: StrokeStyle(lineWidth: 8, lineCap: .round))
            Circle().trim(from: 0.5, to: 0.5 + 0.5 * angle / 180)
                .stroke(.tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
        }
        .padding(.top, 30)
    }
}

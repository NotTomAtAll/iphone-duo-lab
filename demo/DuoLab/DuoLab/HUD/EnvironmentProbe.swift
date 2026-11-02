import SwiftUI
import UIKit

/// What the system is handing the app right now. Read live, never cached (D10).
struct EnvironmentSnapshot: Equatable {
    struct Region: Equatable, Identifiable {
        let id: String
        let kind: String
        let frame: CGRect
        let margins: EdgeInsets
        let isActive: Bool
    }

    var size: CGSize = .zero
    var safeArea = EdgeInsets()
    var horizontal: UserInterfaceSizeClass?
    var vertical: UserInterfaceSizeClass?
    var regions: [Region] = []

    var sizeClassText: String { "\(Self.name(horizontal)) × \(Self.name(vertical))" }

    static func name(_ sizeClass: UserInterfaceSizeClass?) -> String {
        switch sizeClass {
        case .compact: "compact"
        case .regular: "regular"
        default: "unknown"
        }
    }

    /// The fold's frame, if the system reports an active division.
    var fold: CGRect? { regions.first { $0.kind == "division" && $0.isActive }?.frame }
}

/// Hinge status kept as plain text so views can show it without the hinge types.
struct HingeReading: Equatable {
    var status: String
    var angle: Double?

    static let unknown = HingeReading(status: "waiting for first change", angle: nil)

    init(status: String, angle: Double?) {
        self.status = status
        self.angle = angle
    }

    init(_ context: DeviceHingeContext) {
        guard let hinge = context.hinge else {
            self.init(status: "no hinge", angle: nil)
            return
        }
        let status: String = switch hinge.status {
        case .closed: "closed"
        case .partiallyOpen: "partially open"
        case .fullyOpen: "fully open"
        default: "other"
        }
        self.init(status: status, angle: hinge.angle.degrees)
    }

    init(_ update: UIHingeInteraction.Update) {
        guard let hinge = update.hinge else {
            self.init(status: "no hinge", angle: nil)
            return
        }
        let status: String = switch hinge.status {
        case .closed: "closed"
        case .partiallyOpen: "partially open"
        case .fullyOpen: "fully open"
        default: "other"
        }
        self.init(status: status, angle: hinge.angle * 180 / .pi)
    }
}

/// Hands the current hinge state to `action` as soon as it is in a window, then on every change.
/// SwiftUI's `onHingeChange` reports changes only; UIKit's interaction also reports the initial
/// state, which is what a reading needs at launch before anything has moved.
struct HingeSeed: UIViewRepresentable {
    var action: (HingeReading) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        let coordinator = context.coordinator
        view.addInteraction(UIHingeInteraction { _, update in
            // A nil hinge only means the view left the window; keep the last real reading.
            guard update.hinge != nil else { return }
            coordinator.action(HingeReading(update))
        })
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) { context.coordinator.action = action }

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    final class Coordinator {
        var action: (HingeReading) -> Void
        init(action: @escaping (HingeReading) -> Void) { self.action = action }
    }
}

/// Measures the full window (ignoring safe areas) and passes a snapshot to `content`.
struct EnvironmentProbe<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontal
    @Environment(\.verticalSizeClass) private var vertical
    let content: (EnvironmentSnapshot) -> Content

    init(@ViewBuilder content: @escaping (EnvironmentSnapshot) -> Content) {
        self.content = content
    }

    var body: some View {
        // The outer reader respects the safe area, so its proxy reports the insets.
        // The inner one ignores it, so its size and region frames are in window space.
        GeometryReader { inset in
            GeometryReader { full in
                content(snapshot(full, safeArea: inset.safeAreaInsets))
            }
            .ignoresSafeArea()
        }
    }

    private func snapshot(_ proxy: GeometryProxy, safeArea: EdgeInsets) -> EnvironmentSnapshot {
        var regions: [EnvironmentSnapshot.Region] = []
        for (kind, name) in [(ReservedRegion.Kind.division, "division"), (.occlusion, "occlusion")] {
            for (index, region) in proxy.reservedRegions(kind: kind, options: .includeInactive).enumerated() {
                regions.append(.init(id: "\(name)-\(index)", kind: name, frame: region.frame,
                                     margins: region.margins, isActive: region.isActive))
            }
        }
        return EnvironmentSnapshot(size: proxy.size, safeArea: safeArea,
                                   horizontal: horizontal, vertical: vertical, regions: regions)
    }
}

/// Reserved regions in a view's own coordinate space, for layout decisions inside a lab.
struct RegionReader<Content: View>: View {
    @Environment(\.simulatedFold) private var simulatedFold
    let content: (_ size: CGSize, _ folds: [CGRect], _ occlusions: [CGRect]) -> Content

    init(@ViewBuilder content: @escaping (_ size: CGSize, _ folds: [CGRect], _ occlusions: [CGRect]) -> Content) {
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            let real = proxy.reservedRegions(kind: .division).filter(\.isActive).map(\.frame)
            let folds = simulatedFold.map { [$0] } ?? real
            let occlusions = proxy.reservedRegions(kind: .occlusion).filter(\.isActive).map(\.frame)
            content(proxy.size, folds, occlusions)
        }
    }
}

/// Thumbnails render labs off-device, so they pass a stand-in fold and a flag.
extension EnvironmentValues {
    @Entry var simulatedFold: CGRect? = nil
    @Entry var isThumbnail = false
}

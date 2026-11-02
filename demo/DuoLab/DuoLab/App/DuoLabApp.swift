import SwiftUI
import UIKit
import os

@main
struct DuoLabApp: App {
    @State private var router: AppRouter

    init() {
        LaunchTimeline.mark("app init")
        // Launch arguments are applied before the first frame, so a link lands on its screen
        // instead of drawing the home screen first and then switching.
        let router = AppRouter()
        if let link = DeepLink.parse(arguments: ProcessInfo.processInfo.arguments) {
            router.handle(link)
        }
        _router = State(initialValue: router)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .onOpenURL { url in
                    if let link = DeepLink.parse(url: url) { router.handle(link) }
                }
                .task {
                    LaunchTimeline.mark("root task")
                    LaunchTimeline.startProbe()
                }
        }
    }
}

/// The shell is a native TabView, so it shows the system's own bar behavior per pose.
struct RootView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        let linked = router.preview.flatMap { $0.entrance == .linked ? $0 : nil }
        ZStack {
            TabView(selection: $router.tab) {
                Tab("Topics", systemImage: "list.bullet.rectangle.fill", value: RootTab.topics) {
                    TopicsView()
                }
                Tab("Device", systemImage: "ruler.fill", value: RootTab.device) {
                    DeviceView()
                }
            }
            .duoChrome()
            .accessibilityHidden(linked != nil)
            // An option opened by a link: drawn here rather than in a cover (see `PreviewEntrance.linked`).
            if let linked {
                PreviewScreen(target: linked)
                    .id(linked)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .fullScreenCover(isPresented: tourShown, onDismiss: tourDidClose) {
            TourScreen(launch: router.tour ?? TourLaunch())
        }
        .onAppear { LaunchCache.captureIfNeeded() }
    }

    private var tourShown: Binding<Bool> {
        Binding(get: { router.tour != nil }, set: { if !$0 { router.tour = nil } })
    }

    /// "Open this topic": the option fades in over its topic, without the cover's own slide.
    private func tourDidClose() {
        guard let target = router.takeTourExit() else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { router.preview = target }
    }
}

/// Launch timing, for measuring how soon the first screen takes touches. Off unless the app is
/// launched with `-duolab.timeline 1`; then each event is logged (category "timeline") with the
/// seconds since the process started, and every touch the app receives is logged too.
enum LaunchTimeline {
    static let enabled = UserDefaults.standard.bool(forKey: "duolab.timeline")
    private static let log = Logger(subsystem: "duolab", category: "timeline")

    /// Seconds since the process started (kernel start time, so it includes pre-main).
    static var now: Double {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { return 0 }
        let start = info.kp_proc.p_un.__p_starttime
        let started = Double(start.tv_sec) + Double(start.tv_usec) / 1_000_000
        return Date().timeIntervalSince1970 - started
    }

    static func mark(_ event: @autoclosure () -> String) {
        guard enabled else { return }
        let text = event()
        let stamp = String(format: "%6.3f", now)
        log.notice("TL \(stamp, privacy: .public) \(text, privacy: .public)")
    }

    /// For 6 s: logs touches reaching any window, and changes in what UIKit is doing (scene state,
    /// key window, presentations in flight, transition coordinators).
    static func startProbe() {
        guard enabled else { return }
        Task { @MainActor in
            var last = ""
            let end = ContinuousClock.now + .seconds(6)
            while ContinuousClock.now < end {
                let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
                for window in scene?.windows ?? [] where !(window.gestureRecognizers ?? []).contains(where: { $0 is TouchProbe }) {
                    window.addGestureRecognizer(TouchProbe())
                }
                let state = describe(scene)
                if state != last { mark("state " + state); last = state }
                try? await Task.sleep(for: .milliseconds(20))
            }
        }
    }

    private static func describe(_ scene: UIWindowScene?) -> String {
        guard let scene else { return "no scene" }
        let phase: String = switch scene.activationState {
        case .foregroundActive: "active"
        case .foregroundInactive: "inactive"
        case .background: "background"
        default: "unattached"
        }
        let windows = scene.windows.map { w in
            "\(w.isKeyWindow ? "*" : "")\(Int(w.windowLevel.rawValue))\(w.isHidden ? "h" : "v")"
        }.joined(separator: ",")
        var chain: [String] = []
        var vc = scene.keyWindow?.rootViewController
        while let current = vc {
            var flags = ""
            if current.isBeingPresented { flags += "+presenting" }
            if current.isBeingDismissed { flags += "+dismissing" }
            if current.transitionCoordinator != nil { flags += "+transition" }
            if !flags.isEmpty || current.presentingViewController != nil {
                chain.append(String(describing: type(of: current)).prefix(28) + flags)
            }
            vc = current.presentedViewController
        }
        return "\(phase) windows[\(windows)] presented[\(chain.joined(separator: " > "))]"
    }

    /// Sees every touch on its window and never takes part in recognition.
    private final class TouchProbe: UIGestureRecognizer {
        init() {
            super.init(target: nil, action: nil)
            cancelsTouchesInView = false
            delaysTouchesBegan = false
            delaysTouchesEnded = false
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            if let touch = touches.first, let view = view {
                let p = touch.location(in: view)
                let hit = view.hitTest(p, with: event).map { String(describing: type(of: $0)).prefix(40) } ?? "nil"
                LaunchTimeline.mark(String(format: "touch began %.0f,%.0f hit ", p.x, p.y) + hit)
            }
            state = .failed
        }

        override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
        override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    }
}

extension View {
    /// With the timeline on, logs every tap SwiftUI delivers to this view (alongside its own gestures).
    @ViewBuilder func launchTimelineTaps(_ name: String) -> some View {
        if LaunchTimeline.enabled {
            simultaneousGesture(SpatialTapGesture().onEnded { value in
                LaunchTimeline.mark(String(format: "swiftui tap %.0f,%.0f on ", value.location.x, value.location.y) + name)
            })
        } else {
            self
        }
    }
}

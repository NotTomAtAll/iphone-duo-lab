import SwiftUI
import UIKit

@main
struct DuoLabApp: App {
    @State private var router: AppRouter

    init() {
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

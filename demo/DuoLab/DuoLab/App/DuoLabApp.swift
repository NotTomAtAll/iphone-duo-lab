import SwiftUI

@main
struct DuoLabApp: App {
    @State private var router = AppRouter()
    @State private var decisions = DecisionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(decisions)
                .onOpenURL { url in
                    if let link = DeepLink.parse(url: url) { router.handle(link) }
                }
                .task {
                    if let link = DeepLink.parse(arguments: ProcessInfo.processInfo.arguments) {
                        router.handle(link)
                    }
                }
        }
    }
}

/// The shell is a native TabView, so it shows the system's own bar behavior per pose.
struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(DecisionStore.self) private var decisions

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            Tab("Explore", systemImage: "square.grid.2x2.fill", value: RootTab.topics) {
                GalleryView()
            }
            Tab("Playbook", systemImage: "checklist", value: RootTab.playbook) {
                PlaybookView()
            }
            .badge(decisions.decidedCount)
            Tab("Device", systemImage: "ruler.fill", value: RootTab.device) {
                DeviceView()
            }
        }
        .duoChrome()
        .onAppear { LaunchCache.captureIfNeeded() }
    }
}

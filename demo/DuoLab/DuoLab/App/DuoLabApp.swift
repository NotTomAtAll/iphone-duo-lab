import SwiftUI

@main
struct DuoLabApp: App {
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
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

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            Tab("Topics", systemImage: "list.bullet.rectangle.fill", value: RootTab.topics) {
                TopicsView()
            }
            Tab("Device", systemImage: "ruler.fill", value: RootTab.device) {
                DeviceView()
            }
        }
        .duoChrome()
        .onAppear { LaunchCache.captureIfNeeded() }
    }
}

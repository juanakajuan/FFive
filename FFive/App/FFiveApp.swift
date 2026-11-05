import SwiftUI
import SwiftData
import FFiveCore

@main
struct FFiveApp: App {
    let store: Store

    init() {
        let mode = LaunchMode()
        DemoLaunch.configure(mode)
        store = Store(inMemory: mode.isDemo)
        if mode.isDemo { DemoSeed.seed(into: store) }
        Theme.applyNavigationBarAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .environment(store)
        }
        .modelContainer(store.container)
    }
}

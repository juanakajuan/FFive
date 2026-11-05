import SwiftUI
import SwiftData
import FFiveCore

@main
struct FFiveApp: App {
    let store: Store

    init() {
        store = Store(inMemory: DemoLaunch.isEnabled)
        if DemoLaunch.isEnabled { DemoSeed.seed(into: store) }
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

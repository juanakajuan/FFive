import FFiveCore
import SwiftData
import SwiftUI

@main
struct FFiveApp: App {
    let store: Store
    let sync: SyncMonitor

    init() {
        let mode = DemoLaunch.mode
        if mode.animationsDisabled { UIView.setAnimationsEnabled(false) }
        store = Store(inMemory: mode.isDemo)
        if mode.isDemo { DemoSeed.seed(into: store) }
        sync = SyncMonitor(enabled: !mode.isDemo)
        Theme.applyNavigationBarAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .transaction {
                    if DemoLaunch.mode.animationsDisabled {
                        $0.disablesAnimations = true
                        $0.animation = nil
                    }
                }
                .environment(store)
                .environment(sync)
        }
        .modelContainer(store.container)
    }
}

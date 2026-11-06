import FFiveCore
import SwiftData
import SwiftUI

@main
struct FFiveApp: App {
    let store: Store
    let sync: SyncMonitor
    let animationsDisabled: Bool

    init() {
        let mode = LaunchMode()
        DemoLaunch.configure(mode)
        animationsDisabled = mode.animationsDisabled
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
                    if animationsDisabled {
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

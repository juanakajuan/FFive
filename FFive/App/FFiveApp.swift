import FFiveCore
import SwiftData
import SwiftUI

@main
struct FFiveApp: App {
    let store: Store
    let animationsDisabled: Bool

    init() {
        let mode = LaunchMode()
        DemoLaunch.configure(mode)
        animationsDisabled = mode.animationsDisabled
        if mode.animationsDisabled { UIView.setAnimationsEnabled(false) }
        store = Store(inMemory: mode.isDemo)
        if mode.isDemo { DemoSeed.seed(into: store) }
        Theme.applyNavigationBarAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .transaction {
                    if animationsDisabled {
                        $0.disablesAnimations = true
                        $0.animation = nil
                    }
                }
                .environment(store)
        }
        .modelContainer(store.container)
    }
}

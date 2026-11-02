import SwiftUI
import SwiftData

@main
struct FFiveApp: App {
    let container: ModelContainer

    init() {
        container = AppStore.makeContainer(inMemory: DemoLaunch.isEnabled)
        if DemoLaunch.isEnabled { DemoSeed.seed(container.mainContext) }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}

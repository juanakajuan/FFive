import SwiftUI
import SwiftData

@main
struct WorkoutApp: App {
    let container = AppStore.makeContainer(inMemory: false)

    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}

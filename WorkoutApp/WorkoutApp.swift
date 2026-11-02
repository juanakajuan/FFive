import SwiftUI
import SwiftData

@main
struct WorkoutApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: Workout.self)
    }
}

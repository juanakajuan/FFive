import SwiftUI
import Observation

enum AppTab: Hashable { case workout, mesos, templates, exercises, more }

/// Cross-tab navigation: another tab can send the lifter to a session on the Workout tab.
@Observable
final class AppRouter {
    var tab: AppTab = [.progress, .strength].contains(DemoLaunch.route) ? .more : .workout
    /// A day of the active block the Workout tab should show instead of the next session.
    var focus: SessionKey?

    func openSession(_ key: SessionKey) {
        focus = key
        tab = .workout
    }
}

struct RootView: View {
    @State private var router = AppRouter()

    var body: some View {
        TabView(selection: $router.tab) {
            TrainView()
                .tabItem { Label("Workout", systemImage: router.tab == .workout ? "calendar.circle.fill" : "calendar") }
                .tag(AppTab.workout)
            MesosView()
                .tabItem { Label("Mesos", systemImage: router.tab == .mesos ? "folder.fill" : "folder") }
                .tag(AppTab.mesos)
            TemplatesView()
                .tabItem { Label("Templates", systemImage: router.tab == .templates ? "square.grid.2x2.fill" : "square.grid.2x2") }
                .tag(AppTab.templates)
            ExercisesView()
                .tabItem { Label("Exercises", systemImage: "dumbbell") }
                .tag(AppTab.exercises)
            MoreView()
                .tabItem { Label("More", systemImage: router.tab == .more ? "ellipsis.circle.fill" : "ellipsis.circle") }
                .tag(AppTab.more)
        }
        .environment(router)
        .tint(Theme.text)
    }
}

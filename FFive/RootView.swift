import SwiftUI
import Observation

enum AppTab: CaseIterable, Hashable {
    case workout, mesos, templates, exercises, more

    var title: String {
        switch self {
        case .workout: "Workout"
        case .mesos: "Mesos"
        case .templates: "Templates"
        case .exercises: "Exercises"
        case .more: "More"
        }
    }

    func icon(selected: Bool) -> String {
        switch self {
        case .workout: selected ? "calendar.circle.fill" : "calendar"
        case .mesos: selected ? "folder.fill" : "folder"
        case .templates: selected ? "square.grid.2x2.fill" : "square.grid.2x2"
        case .exercises: "dumbbell"
        case .more: selected ? "ellipsis.circle.fill" : "ellipsis.circle"
        }
    }
}

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
    @State private var keyboardShown = false

    var body: some View {
        // The system TabView draws a floating glass bar on recent iOS; the design calls for a flat,
        // full-width bar. Like the design's pages, a tab starts fresh each time it is opened.
        Group {
            switch router.tab {
            case .workout: TrainView()
            case .mesos: MesosView()
            case .templates: TemplatesView()
            case .exercises: ExercisesView()
            case .more: MoreView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !keyboardShown { TabBar(selection: $router.tab) }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardShown = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardShown = false }
        .environment(router)
        .tint(Theme.text)
    }
}

private struct TabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let selected = tab == selection
                Button { selection = tab } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon(selected: selected))
                            .font(.system(size: 22))
                            .frame(height: 26)
                        Text(tab.title).font(.system(size: 10.5))
                    }
                    .foregroundStyle(selected ? Theme.text : Theme.secondary)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 2)
        .background(Theme.surface.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(Theme.hairline).frame(height: 1) }
    }
}

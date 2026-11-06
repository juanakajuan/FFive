import FFiveCore
import Observation
import SwiftData
import SwiftUI

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

    var a11y: A11y {
        switch self {
        case .workout: .tabWorkout
        case .mesos: .tabMesos
        case .templates: .tabTemplates
        case .exercises: .tabExercises
        case .more: .tabMore
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

struct SessionFocus: Equatable {
    let meso: PersistentIdentifier
    let key: SessionKey
}

@Observable
final class AppRouter {
    var tab: AppTab = [.progress, .strength].contains(DemoLaunch.route) ? .more : .workout
    var focus: SessionFocus?
    /// The block that just ended, whose summary shows over every tab until it is dismissed.
    var endedMeso: Mesocycle?

    func openSession(_ key: SessionKey, in meso: Mesocycle) {
        focus = SessionFocus(meso: meso.persistentModelID, key: key)
        tab = .workout
    }

    @MainActor
    func end(_ meso: Mesocycle, store: Store) {
        store.endMesocycle(meso)
        endedMeso = meso
    }
}

struct RootView: View {
    @Environment(Store.self) private var store
    @State private var router = AppRouter()
    @State private var keyboardShown = false

    var body: some View {
        // The system TabView draws a floating glass bar on recent iOS; the design calls for a flat,
        // full-width bar. Like the design's pages, a tab starts fresh each time it is opened.
        // Stacked, not a bottom safe-area inset: the inset's height never reached views inside each tab's
        // NavigationStack, so anything they pinned to their bottom edge sat under the bar.
        VStack(spacing: 0) {
            Group {
                switch router.tab {
                case .workout: TrainView()
                case .mesos: MesosView()
                case .templates: TemplatesView()
                case .exercises: ExercisesView()
                case .more: MoreView()
                }
            }
            .frame(maxHeight: .infinity)
            if !keyboardShown { TabBar(selection: $router.tab) }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardShown = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardShown = false
        }
        .dismissesKeyboardOnTapOutside()
        .environment(router)
        .tint(Theme.text)
        .preferredColorScheme(store.settings.appearance.colorScheme)
        .sheet(item: $router.endedMeso) { MesoSummarySheet(meso: $0) }
        .alert(
            "Your last change was not saved",
            isPresented: Binding(get: { store.failure != nil }, set: { if !$0 { store.dismissFailure() } })
        ) {
        } message: {
            Text(store.failure?.localizedDescription ?? "")
        }
    }
}

private struct TabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let selected = tab == selection
                Button {
                    selection = tab
                } label: {
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
                .a11y(tab.a11y)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 2)
        .background(Theme.surface.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(Theme.hairline).frame(height: 1) }
    }
}

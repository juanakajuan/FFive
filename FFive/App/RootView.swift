import FFiveCore
import Observation
import SwiftData
import SwiftUI

enum AppTab: CaseIterable, Hashable {
    case workout, mesos, templates, exercises, more

    var title: String {
        switch self {
        case .workout: "Workout"
        case .mesos: "Mesocycles"
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

    private var symbol: String {
        switch self {
        case .workout: "calendar.circle"
        case .mesos: "folder"
        case .templates: "square.grid.2x2"
        case .exercises: "dumbbell"
        case .more: "ellipsis.circle"
        }
    }

    func icon(selected: Bool) -> String { selected ? symbol + ".fill" : symbol }
}

struct SessionFocus: Equatable {
    let meso: PersistentIdentifier
    let key: SessionKey
}

@MainActor
@Observable
final class AppRouter {
    var tab: AppTab = [.progress, .strength].contains(DemoLaunch.route) ? .more : .workout
    var focus: SessionFocus?
    /// The block that just ended, whose summary shows over every tab until it is dismissed.
    var endedMeso: Mesocycle?
    /// Counts finished workouts and started or ended mesocycles; RootView plays a success haptic on each.
    private(set) var milestones = 0

    func openSession(_ key: SessionKey, in meso: Mesocycle) {
        focus = SessionFocus(meso: meso.persistentModelID, key: key)
        tab = .workout
    }

    func end(_ meso: Mesocycle, store: Store) {
        store.endMesocycle(meso)
        endedMeso = meso
        milestones += 1
    }

    func finish(_ workout: Workout, store: Store) {
        store.finish(workout)
        focus = nil
        milestones += 1
    }

    /// Starts `draft`, and returns false when another mesocycle is still active.
    func start(_ draft: MesoDraft, store: Store) -> Bool {
        guard (try? store.startMesocycle(draft)) != nil else { return false }
        milestones += 1
        return true
    }

    func delete(_ meso: Mesocycle, store: Store) {
        if focus?.meso == meso.persistentModelID { focus = nil }
        if endedMeso === meso { endedMeso = nil }
        store.deleteMesocycle(meso)
    }

    func deleteAllData(store: Store) {
        focus = nil
        endedMeso = nil
        store.deleteAllData()
    }
}

struct RootView: View {
    @Environment(Store.self) private var store
    @State private var router = AppRouter()
    @State private var keyboardShown = false
    @State private var whatsNew: [Changelog.DayGroup] = []

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
        .sensoryFeedback(.success, trigger: router.milestones)
        .preferredColorScheme(store.settings.appearance.colorScheme)
        .sheet(item: $router.endedMeso) { MesoSummarySheet(meso: $0) }
        .sheet(
            isPresented: Binding(get: { !whatsNew.isEmpty }, set: { if !$0 { whatsNew = [] } }),
            onDismiss: { store.settings.changelogSeenVersion = Changelog.runningVersion }
        ) {
            WhatsNewSheet(groups: whatsNew)
        }
        .task { showWhatsNewAfterUpdate() }
        .alert(
            "Your last change was not saved",
            isPresented: Binding(get: { store.failure != nil }, set: { if !$0 { store.dismissFailure() } })
        ) {
        } message: {
            Text(store.failure?.localizedDescription ?? "")
        }
    }
}

extension RootView {
    /// Opens What's New on the first launch of a newer version. A fresh install only records the version.
    fileprivate func showWhatsNewAfterUpdate() {
        guard !DemoLaunch.isDemo else { return }
        let current = Changelog.runningVersion
        let settings = store.settings
        guard settings.changelogSeenVersion != current else { return }
        let unseen = Changelog.bundled.unseen(
            lastSeen: settings.changelogSeenVersion, current: current, hasHistory: store.hasTrainingHistory)
        if unseen.isEmpty {
            settings.changelogSeenVersion = current
        } else {
            whatsNew = unseen
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
                        Text(tab.title).font(Theme.caption)
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
        .overlay(alignment: .top) { Hairline() }
    }
}

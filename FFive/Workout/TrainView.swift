import FFiveCore
import SwiftData
import SwiftUI

enum WorkoutTabContent: Equatable {
    case session(Workout)
    case unbuilt(Mesocycle, SessionKey)
    case blockComplete(Mesocycle)
    case empty

    static func resolve(meso: Mesocycle?, focus: SessionFocus?, quickWorkout: Workout?) -> WorkoutTabContent {
        guard let meso else { return quickWorkout.map(Self.session) ?? .empty }
        if let focus, focus.meso == meso.persistentModelID, meso.allKeys.contains(focus.key),
            meso.status(at: focus.key).isOpen
        {
            return day(focus.key, of: meso)
        }
        if let quickWorkout { return .session(quickWorkout) }
        if let next = meso.nextUp { return day(next, of: meso) }
        return .blockComplete(meso)
    }

    private static func day(_ key: SessionKey, of meso: Mesocycle) -> WorkoutTabContent {
        meso.workout(at: key).map(Self.session) ?? .unbuilt(meso, key)
    }
}

struct TrainView: View {
    @Environment(Store.self) private var store
    @Environment(AppRouter.self) private var router
    @Query(Mesocycle.active) private var activeMesos: [Mesocycle]
    @Query(Workout.open) private var openWorkouts: [Workout]

    @State private var showingBuilder = false
    @State private var showingSchedule = false
    @State private var ending: Mesocycle?

    private var openQuickWorkout: Workout? { openWorkouts.first { $0.mesocycle == nil } }

    var body: some View {
        let content = WorkoutTabContent.resolve(
            meso: activeMesos.first, focus: router.focus, quickWorkout: openQuickWorkout)
        NavigationStack {
            Group {
                switch content {
                case .session(let workout):
                    ActiveWorkoutView(
                        workout: workout, activeMeso: activeMesos.first, openQuickWorkout: openQuickWorkout
                    )
                    .id(workout.persistentModelID)
                case .unbuilt:
                    Color.clear
                case .blockComplete(let meso):
                    blockCompleteView(meso)
                case .empty:
                    // With the navigation bar hidden, cards would otherwise scroll visibly under the status bar.
                    // The other screens pin a header whose fill covers it.
                    noMesoView.clipped()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.page)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingBuilder) { MesoBuilderView() }
            .task {
                if DemoLaunch.take(.builder) { showingBuilder = true }
            }
            .task(id: content) {
                switch content {
                case .unbuilt(let meso, let key): store.buildSession(meso, at: key)
                case .session(let workout): store.show(workout)
                default: break
                }
            }
        }
    }

    private var noMesoView: some View {
        ScrollView {
            VStack(spacing: 16) {
                EmptyState(
                    "No active mesocycle", systemImage: "calendar",
                    message: "Plan a mesocycle of 3 to 6 hard weeks and a deload, or log a quick workout with no plan."
                ) {
                    Button("Plan a Mesocycle") { showingBuilder = true }
                        .buttonStyle(.primary)
                        .a11y(.workoutPlan)
                    Button("Quick Workout") {
                        WorkoutTabActions.showQuickWorkout(openQuickWorkout, router: router, store: store)
                    }
                    .buttonStyle(.secondary)
                    .a11y(.workoutQuick)
                }

                StatsRow(stats: store.weekStats())
                    .padding(.horizontal, Theme.gutter)
            }
        }
    }

    private func blockCompleteView(_ meso: Mesocycle) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Label("Every session is done", systemImage: "flag.checkered")
                    .font(Theme.cardTitle)
                    .foregroundStyle(Theme.text)
                Text("Every session is done or skipped, deload included. End this mesocycle to plan the next one.")
                    .font(Theme.detail)
                    .foregroundStyle(Theme.secondary)
                Button("End Mesocycle") { ending = meso }
                    .buttonStyle(.primary)
                    .a11y(.workoutEnd)
                    .padding(.top, 4)
                Button("Quick Workout") {
                    WorkoutTabActions.showQuickWorkout(openQuickWorkout, router: router, store: store)
                }
                .buttonStyle(.secondary)
                .a11y(.workoutQuick)
            }
            .surfaceCard()
            .padding(.vertical, Theme.gutter)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            WorkoutHeader(title: Text("Mesocycle Complete"), subtitle: Text(meso.name), progress: 1) {
                Button {
                    showingSchedule = true
                } label: {
                    ActionIcon.calendar
                }
                .accessibilityLabel("Schedule")
                .a11y(.workoutSchedule)
            }
        }
        .sheet(isPresented: $showingSchedule) { ScheduleSheet(meso: meso, week: meso.accumulationWeeks) }
        .endMesocycleDialog($ending) { WorkoutTabActions.end($0, router: router, store: store) }
    }
}

@MainActor
enum WorkoutTabActions {
    static func showQuickWorkout(_ open: Workout?, router: AppRouter, store: Store) {
        if open == nil { store.startQuickWorkout() }
        router.focus = nil
    }

    static func end(_ meso: Mesocycle, router: AppRouter, store: Store) {
        router.end(meso, store: store)
        router.focus = nil
    }
}

struct ScheduleSheet: View {
    let meso: Mesocycle
    let week: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @Environment(Store.self) private var store
    @State private var trainAfterAll: SessionKey?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    MesoScheduleGrid(meso: meso, onOpen: open, onSkipped: { trainAfterAll = $0 })
                    MesoLengthCard(meso: meso)
                    WeekVolumeCard(meso: meso, week: week)
                }
                .padding(Theme.gutter)
            }
            .background(Theme.page)
            .trainAfterAllDialog($trainAfterAll, of: meso, store: store, onOpen: open)
            .navigationTitle(meso.name)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .a11y(.sheetDone)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func open(_ key: SessionKey) {
        router.openSession(key, in: meso)
        dismiss()
    }
}

#Preview {
    let store = Store(inMemory: true)
    return TrainView()
        .environment(AppRouter())
        .environment(store)
        .modelContainer(store.container)
        .preferredColorScheme(.dark)
}

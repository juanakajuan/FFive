import SwiftUI
import SwiftData
import FFiveCore

/// What the Workout tab shows. Resolving it only reads stored state; building a block day happens in `.task(id:)`.
enum WorkoutTabContent: Equatable {
    /// An open workout: the focused block day, the open quick workout, or the block's next session.
    case session(Workout)
    /// A block day with no workout row yet.
    case unbuilt(Mesocycle, SessionKey)
    case blockComplete(Mesocycle)
    case empty

    static func resolve(meso: Mesocycle?, focus: SessionFocus?, quickWorkout: Workout?) -> WorkoutTabContent {
        guard let meso else { return quickWorkout.map(Self.session) ?? .empty }
        if let focus, focus.meso == meso.persistentModelID, meso.allKeys.contains(focus.key), meso.status(at: focus.key).isOpen {
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
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Query(filter: #Predicate<Mesocycle> { $0.finishedDate == nil }, sort: \Mesocycle.startDate, order: .reverse)
    private var activeMesos: [Mesocycle]
    @Query(filter: #Predicate<Workout> { $0.endDate == nil }, sort: \Workout.startDate, order: .reverse)
    private var openWorkouts: [Workout]
    @Query(filter: #Predicate<Workout> { $0.endDate != nil })
    private var finishedWorkouts: [Workout]

    @AppStorage("weightUnit") private var unit: WeightUnit = .lb

    @State private var showingBuilder = false
    @State private var showingSchedule = false
    @State private var confirmEnd = false

    private var openQuickWorkout: Workout? { openWorkouts.first { $0.mesocycle == nil } }

    var body: some View {
        let content = WorkoutTabContent.resolve(meso: activeMesos.first, focus: router.focus, quickWorkout: openQuickWorkout)
        NavigationStack {
            Group {
                switch content {
                case .session(let workout):
                    ActiveWorkoutView(workout: workout, activeMeso: activeMesos.first, openQuickWorkout: openQuickWorkout)
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
                case .unbuilt(let meso, let key):
                    _ = MesoPlanner.workout(for: meso, at: key, unit: unit, in: context)
                    try? context.save()
                case .session(let workout) where workout.mesocycle != nil && workout.completedSets == 0:
                    // A block day is built as soon as the tab shows it. Until a set is logged its clock restarts
                    // each time it is shown, so duration and the soreness lookback count from when training began.
                    workout.startDate = .now
                default:
                    break
                }
            }
        }
    }

    private var noMesoView: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Train in mesocycles")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.text)
                    Text("Plan a block of 3 to 6 hard weeks and a deload. Every week, your sets, loads, and reps adjust to how the last sessions felt.")
                        .font(Theme.detail)
                        .foregroundStyle(Theme.secondary)
                    Button("Plan a Mesocycle") { showingBuilder = true }
                        .buttonStyle(.wideFilled)
                        .padding(.top, 4)
                    Button("Quick Workout") { WorkoutTabActions.showQuickWorkout(openQuickWorkout, router: router, in: context) }
                        .buttonStyle(.wideOutlined)
                    Text("Log a free-form session with no plan.")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.secondary)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 8)
                .surfaceCard()

                StatsRow(history: finishedWorkouts)
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
                Button("End Mesocycle") { confirmEnd = true }
                    .buttonStyle(.wideFilled)
                    .padding(.top, 4)
                Button("Quick Workout") { WorkoutTabActions.showQuickWorkout(openQuickWorkout, router: router, in: context) }
                    .buttonStyle(.wideOutlined)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 8)
            .surfaceCard()
            .padding(.vertical, 16)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            WorkoutHeader(title: Text("Block complete"), subtitle: Text(meso.name), progress: 1) {
                Button { showingSchedule = true } label: { ActionIcon.calendar }
                    .accessibilityLabel("Schedule")
            }
        }
        .sheet(isPresented: $showingSchedule) { ScheduleSheet(meso: meso, week: meso.accumulationWeeks) }
        .confirmationDialog("End this mesocycle?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End Mesocycle", role: .destructive) { WorkoutTabActions.end(meso, router: router, in: context) }
        } message: {
            Text("Logged sessions stay in Progress. You can plan a new block right after.")
        }
    }
}

/// Actions that change which content the Workout tab shows, shared by the session menu and the empty states.
@MainActor
enum WorkoutTabActions {
    /// Shows the open quick workout, starting one first when none is open.
    static func showQuickWorkout(_ open: Workout?, router: AppRouter, in context: ModelContext) {
        if open == nil {
            context.insert(Workout(name: defaultWorkoutName()))
            try? context.save()
        }
        router.focus = nil
    }

    static func end(_ meso: Mesocycle, router: AppRouter, in context: ModelContext) {
        meso.end(in: context)
        try? context.save()
        router.focus = nil
    }

    private static func defaultWorkoutName() -> String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Morning Workout"
        case 12..<17: "Afternoon Workout"
        default: "Evening Workout"
        }
    }
}

/// The block's week grid and this week's volume. Opening a day shows it on the Workout tab.
struct ScheduleSheet: View {
    let meso: Mesocycle
    let week: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @AppStorage("weightUnit") private var unit: WeightUnit = .lb

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    MesoScheduleGrid(meso: meso) { key in
                        router.openSession(key, in: meso)
                        dismiss()
                    }
                    WeekVolumeCard(meso: meso, week: week, unit: unit)
                }
                .padding(Theme.gutter)
            }
            .background(Theme.page)
            .navigationTitle(meso.name)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct StatsRow: View {
    let history: [Workout]

    var body: some View {
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let thisWeek = history.filter { $0.startDate >= weekStart }
        HStack(spacing: 12) {
            StatTile(title: "This Week", value: "\(thisWeek.count)", icon: "flame.fill")
            StatTile(title: "Time", value: formatDuration(thisWeek.reduce(0) { $0 + $1.duration }), icon: "clock.fill")
            StatTile(title: "All Time", value: "\(history.count)", icon: "trophy.fill")
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    TrainView()
        .environment(AppRouter())
        .modelContainer(AppStore.makeContainer(inMemory: true))
        .preferredColorScheme(.dark)
}

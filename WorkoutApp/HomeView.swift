import SwiftUI
import SwiftData

struct HomeView: View {
    enum EndAction { case finish, discard }

    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Workout> { $0.endDate != nil }, sort: \Workout.startDate, order: .reverse)
    private var history: [Workout]
    @Query(filter: #Predicate<Workout> { $0.endDate == nil })
    private var inProgress: [Workout]

    @AppStorage("weightUnit") private var unit: WeightUnit = .lb
    @AppStorage("restSeconds") private var restSeconds = 90

    @State private var activeWorkout: Workout?
    @State private var pendingEnd: (workout: Workout, action: EndAction)?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    StatsRow(history: history)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section {
                    Button(action: startOrResume) {
                        Label(inProgress.isEmpty ? "Start Workout" : "Resume Workout",
                              systemImage: inProgress.isEmpty ? "plus" : "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 14))
                    .foregroundStyle(.black)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section("History") {
                    if history.isEmpty {
                        ContentUnavailableView("No workouts yet",
                                               systemImage: "dumbbell",
                                               description: Text("Tap Start Workout to log your first session."))
                    }
                    ForEach(history) { workout in
                        NavigationLink(value: workout) {
                            HistoryRow(workout: workout)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { context.delete(history[index]) }
                    }
                }
            }
            .navigationTitle("Workouts")
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
            .toolbar {
                Menu {
                    Picker("Units", selection: $unit) {
                        ForEach(WeightUnit.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Rest Timer", selection: $restSeconds) {
                        ForEach([60, 90, 120, 180], id: \.self) { Text("\($0)s rest").tag($0) }
                    }
                } label: {
                    Image(systemName: "gearshape")
                }
            }
            .fullScreenCover(item: $activeWorkout, onDismiss: applyPendingEnd) { workout in
                ActiveWorkoutView(workout: workout) { action in
                    pendingEnd = (workout, action)
                    activeWorkout = nil
                }
            }
        }
    }

    private func startOrResume() {
        if let current = inProgress.first {
            activeWorkout = current
            return
        }
        let workout = Workout(name: defaultWorkoutName())
        context.insert(workout)
        activeWorkout = workout
    }

    /// Finishing / discarding happens after the cover is gone so no view renders deleted models.
    private func applyPendingEnd() {
        guard let pending = pendingEnd else { return }
        pendingEnd = nil
        let workout = pending.workout
        switch pending.action {
        case .discard:
            context.delete(workout)
        case .finish:
            for exercise in workout.exercises {
                if !exercise.sets.contains(where: \.isDone) {
                    context.delete(exercise)
                } else {
                    for set in exercise.sets where !set.isDone { context.delete(set) }
                }
            }
            workout.endDate = .now
        }
        try? context.save()
    }

    private func defaultWorkoutName() -> String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Morning Workout"
        case 12..<17: "Afternoon Workout"
        default: "Evening Workout"
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
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).foregroundStyle(.tint)
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct HistoryRow: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(workout.name).font(.headline)
                Spacer()
                Text(workout.startDate, format: .dateTime.month(.abbreviated).day())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Label(formatDuration(workout.duration), systemImage: "clock")
                Label("\(workout.completedSets) \(workout.completedSets == 1 ? "set" : "sets")", systemImage: "checkmark.circle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if !workout.exercises.isEmpty {
                Text(workout.sortedExercises.map(\.name).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: Workout.self, inMemory: true)
        .preferredColorScheme(.dark)
}

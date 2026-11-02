import SwiftUI
import SwiftData

struct TrainView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Mesocycle> { $0.finishedDate == nil }, sort: \Mesocycle.startDate, order: .reverse)
    private var activeMesos: [Mesocycle]
    @Query(filter: #Predicate<Workout> { $0.endDate == nil }, sort: \Workout.startDate, order: .reverse)
    private var openWorkouts: [Workout]
    @Query(filter: #Predicate<Workout> { $0.endDate != nil })
    private var finishedWorkouts: [Workout]

    @AppStorage("weightUnit") private var unit: WeightUnit = .lb

    @State private var activeWorkout: Workout?
    @State private var pendingEnd: (workout: Workout, action: SessionEnd)?
    @State private var showingBuilder = false

    private var openQuickWorkout: Workout? { openWorkouts.first { $0.mesocycle == nil } }

    var body: some View {
        NavigationStack {
            Group {
                if let meso = activeMesos.first {
                    MesoDashboard(meso: meso, unit: unit) { open($0, in: meso) }
                } else {
                    noMesoView
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Train")
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { settingsMenu }
            }
            .fullScreenCover(item: $activeWorkout, onDismiss: applyPendingEnd) { workout in
                ActiveWorkoutView(workout: workout) { action in
                    pendingEnd = (workout, action)
                    activeWorkout = nil
                }
            }
            .sheet(isPresented: $showingBuilder) { MesoBuilderView() }
            .task {
                if DemoLaunch.take(.builder) { showingBuilder = true }
                if DemoLaunch.take(.session), let meso = activeMesos.first, let next = meso.nextUp { open(next, in: meso) }
            }
        }
    }

    private var noMesoView: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.largeTitle)
                        .foregroundStyle(.tint)
                    Text("Train in mesocycles").font(.title2.bold())
                    Text("Plan a block of 3 to 6 hard weeks and a deload. Every week, your sets, loads, and reps adjust to how the last sessions felt.")
                        .foregroundStyle(.secondary)
                    Button { showingBuilder = true } label: {
                        Text("Plan a Mesocycle")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 14))
                    .foregroundStyle(.black)
                    .padding(.top, 4)
                }
                .padding(20)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))

                Button(action: startQuickWorkout) {
                    Label(openQuickWorkout == nil ? "Quick Workout" : "Resume Quick Workout",
                          systemImage: openQuickWorkout == nil ? "bolt.fill" : "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 14))
                Text("Log a free-form session with no plan.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                StatsRow(history: finishedWorkouts).padding(.top, 8)
            }
            .padding()
        }
    }

    private var settingsMenu: some View {
        Menu {
            if !activeMesos.isEmpty {
                Button(openQuickWorkout == nil ? "Quick Workout" : "Resume Quick Workout", systemImage: "bolt.fill",
                       action: startQuickWorkout)
            }
            Picker("Units", selection: $unit) {
                ForEach(WeightUnit.allCases) { Text($0.rawValue).tag($0) }
            }
        } label: {
            Image(systemName: "gearshape")
        }
    }

    private func open(_ key: SessionKey, in meso: Mesocycle) {
        let workout = MesoPlanner.workout(for: meso, at: key, unit: unit, in: context)
        try? context.save()
        activeWorkout = workout
    }

    private func startQuickWorkout() {
        if let current = openQuickWorkout {
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
        switch pending.action {
        case .discard: context.delete(pending.workout)
        case .finish: pending.workout.finish(in: context)
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

struct MesoDashboard: View {
    let meso: Mesocycle
    let unit: WeightUnit
    var onOpen: (SessionKey) -> Void

    @Environment(\.modelContext) private var context
    @State private var confirmEnd = false
    @State private var trainAfterAll: SessionKey?

    var body: some View {
        let next = meso.nextUp
        let week = next?.week ?? meso.accumulationWeeks
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(meso.name).font(.title2.bold())
                    HStack(spacing: 8) {
                        Text("Week \(week + 1) of \(meso.totalWeeks)").foregroundStyle(.secondary)
                        PhaseBadge(phase: meso.phase(week: week))
                    }
                }

                if let next {
                    nextCard(next)
                } else {
                    completeCard
                }

                schedule(next: next)
                weekVolume(week)

                if next != nil {
                    Button("End Mesocycle", role: .destructive) { confirmEnd = true }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
            }
            .padding()
        }
        .confirmationDialog("End this mesocycle?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End Mesocycle", role: .destructive, action: endMeso)
        } message: {
            Text("Logged sessions stay in Progress. You can plan a new block right after.")
        }
    }

    private func nextCard(_ key: SessionKey) -> some View {
        let days = meso.sortedDays
        let day = days.indices.contains(key.dayIndex) ? days[key.dayIndex] : nil
        let workout: Workout? = if case .inProgress(let workout) = meso.status(at: key) { workout } else { nil }
        let names = workout?.sortedExercises.map(\.name) ?? day?.sortedSlots.map(\.exerciseName) ?? []
        let inProgress = workout != nil
        return Button { onOpen(key) } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(inProgress ? "In progress" : "Next up")
                        .font(.caption.bold())
                        .textCase(.uppercase)
                    Spacer()
                    Text(meso.phase(week: key.week) == .deload ? "Deload · Day \(key.dayIndex + 1)" : "Week \(key.week + 1) · Day \(key.dayIndex + 1)")
                        .font(.caption.bold())
                }
                .opacity(0.7)
                Text(day?.name ?? "Day \(key.dayIndex + 1)")
                    .font(.title.bold())
                Text(names.prefix(3).joined(separator: " · ") + (names.count > 3 ? " +\(names.count - 3)" : ""))
                    .font(.subheadline)
                    .lineLimit(1)
                    .opacity(0.8)
                Label(inProgress ? "Resume" : "Start Workout", systemImage: inProgress ? "play.fill" : "arrow.right.circle.fill")
                    .font(.headline)
                    .padding(.top, 6)
            }
            .foregroundStyle(.black)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottomTrailing) {
            if meso.canSkip(key) {
                Button { skip(key) } label: {
                    Label("Skip", systemImage: "forward.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.black.opacity(0.75))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(18)
            }
        }
    }

    private var completeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Block complete", systemImage: "flag.checkered")
                .font(.title3.bold())
            Text("Every session is done or skipped, deload included. End this mesocycle to plan the next one.")
                .foregroundStyle(.secondary)
            Button { confirmEnd = true } label: {
                Text("End Mesocycle").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .foregroundStyle(.black)
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private func schedule(next: SessionKey?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Schedule").font(.headline)
            Grid(horizontalSpacing: 6, verticalSpacing: 8) {
                GridRow {
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    ForEach(meso.days.indices, id: \.self) { day in
                        Text("D\(day + 1)")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                    }
                }
                ForEach(0..<meso.totalWeeks, id: \.self) { week in
                    GridRow {
                        Text(week == meso.accumulationWeeks ? "DL" : "W\(week + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(week == next?.week ? Color.primary : Color.secondary)
                            .frame(width: 28, alignment: .leading)
                        ForEach(meso.days.indices, id: \.self) { day in
                            cell(SessionKey(week: week, dayIndex: day), next: next)
                        }
                    }
                }
            }
            Text("Tap a day in the current week to train it, or a finished day to review it. Long-press a day to skip it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .confirmationDialog("Train this day after all?",
                            isPresented: Binding(get: { trainAfterAll != nil }, set: { if !$0 { trainAfterAll = nil } }),
                            titleVisibility: .visible, presenting: trainAfterAll) { key in
            Button("Train Day \(key.dayIndex + 1)") {
                meso.unskip(key)
                onOpen(key)
            }
        }
    }

    @ViewBuilder
    private func cell(_ key: SessionKey, next: SessionKey?) -> some View {
        let status = meso.status(at: key)
        let isCurrentWeek = key.week == next?.week
        switch status {
        case .finished(let workout):
            NavigationLink(value: workout) {
                cellIcon("checkmark.circle.fill", Color.green)
            }
            .buttonStyle(.plain)
        case .skipped:
            if isCurrentWeek {
                Button { trainAfterAll = key } label: { cellIcon("forward.circle", Color.secondary) }
                    .buttonStyle(.plain)
            } else {
                cellIcon("forward.circle", Color.secondary)
            }
        case .upcoming, .inProgress:
            if isCurrentWeek {
                Button { onOpen(key) } label: {
                    if case .inProgress = status {
                        cellIcon("circle.lefthalf.filled", Color.accentColor)
                    } else if key == next {
                        cellIcon("play.circle.fill", Color.accentColor)
                    } else {
                        cellIcon("circle", Color.secondary)
                    }
                }
                .buttonStyle(.plain)
                .contextMenu {
                    if meso.canSkip(key) {
                        Button("Skip Day", systemImage: "forward") { skip(key) }
                    }
                }
            } else {
                cellIcon("circle", Color(.quaternaryLabel))
            }
        }
    }

    private func cellIcon(_ name: String, _ color: Color) -> some View {
        Image(systemName: name)
            .font(.title2)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, minHeight: 34)
            .contentShape(Rectangle())
    }

    private func weekVolume(_ week: Int) -> some View {
        let volumes = MesoPlanner.weeklyVolume(meso, week: week, unit: unit, context: context)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("This Week's Sets").font(.headline)
                Spacer()
                Text("done / planned").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(volumes) { VolumeBar(volume: $0) }
            VolumeLegend()
            Text("Each bar ends at the most weekly sets that muscle can usually recover from.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private func skip(_ key: SessionKey) {
        withAnimation { meso.skip(key, in: context) }
        try? context.save()
    }

    private func endMeso() {
        meso.finishedDate = .now
        try? context.save()
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
        .modelContainer(AppStore.makeContainer(inMemory: true))
        .preferredColorScheme(.dark)
}

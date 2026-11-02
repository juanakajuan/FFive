import SwiftUI
import SwiftData
import Charts

struct ProgressScreen: View {
    private enum Pane: String, CaseIterable, Identifiable {
        case volume = "Volume", strength = "Strength", history = "History"
        var id: Self { self }
    }

    @Environment(\.modelContext) private var context
    @Query(sort: \Mesocycle.startDate, order: .reverse) private var mesos: [Mesocycle]
    @Query(filter: #Predicate<Workout> { $0.endDate != nil }, sort: \Workout.startDate, order: .reverse)
    private var history: [Workout]
    @AppStorage("weightUnit") private var unit: WeightUnit = .lb

    @State private var pane: Pane = DemoLaunch.route == .strength ? .strength : .volume
    @State private var path = NavigationPath()
    @State private var selectedMeso: PersistentIdentifier?
    @State private var selectedWeek: Int?

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    Picker("View", selection: $pane) {
                        ForEach(Pane.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                switch pane {
                case .volume: volume
                case .strength: strength
                case .history: historyList
                }
            }
            .navigationTitle("Progress")
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
            .navigationDestination(for: StrengthSeries.self) { ExerciseTrendView(series: $0, unit: unit) }
            .task {
                if DemoLaunch.take(.strength), let richest = StrengthSeries.all(from: history).max(by: { $0.points.count < $1.points.count }) {
                    path.append(richest)
                }
            }
        }
    }

    // MARK: Volume

    @ViewBuilder
    private var volume: some View {
        if let meso = mesos.first(where: { $0.persistentModelID == selectedMeso }) ?? mesos.first(where: { $0.finishedDate == nil }) ?? mesos.first {
            let week = min(selectedWeek ?? meso.nextUp?.week ?? meso.accumulationWeeks, meso.accumulationWeeks)
            let volumes = MesoPlanner.weeklyVolume(meso, week: week, unit: unit, context: context)
            Section {
                if mesos.count > 1 {
                    Picker("Mesocycle", selection: Binding(get: { meso.persistentModelID }, set: { selectedMeso = $0; selectedWeek = nil })) {
                        ForEach(mesos) { Text($0.name).tag($0.persistentModelID) }
                    }
                }
                Picker("Week", selection: Binding(get: { week }, set: { selectedWeek = $0 })) {
                    ForEach(0..<meso.totalWeeks, id: \.self) { index in
                        Text(index == meso.accumulationWeeks ? "DL" : "W\(index + 1)").tag(index)
                    }
                }
                .pickerStyle(.segmented)
                VolumeChart(volumes: volumes)
                    .padding(.vertical, 8)
                VolumeLegend(includesMaximum: true)
            } header: {
                Text("Sets per muscle · \(meso.phase(week: week) == .deload ? "Deload" : "Week \(week + 1)")")
            } footer: {
                Text("Aim to finish most weeks inside the green range. The red tick is the most a muscle usually recovers from; feedback keeps you below it.")
            }
        } else {
            ContentUnavailableView("No mesocycle yet",
                                   systemImage: "chart.bar.xaxis",
                                   description: Text("Plan a mesocycle on the Train tab to see weekly sets against each muscle's landmarks."))
                .listRowBackground(Color.clear)
        }
    }

    // MARK: Strength

    @ViewBuilder
    private var strength: some View {
        let series = StrengthSeries.all(from: history)
        if series.isEmpty {
            ContentUnavailableView("No loaded sets yet",
                                   systemImage: "chart.line.uptrend.xyaxis",
                                   description: Text("Finish a session with weighted sets to start tracking estimated 1RM."))
                .listRowBackground(Color.clear)
        } else {
            Section {
                ForEach(series) { item in
                    NavigationLink(value: item) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name).font(.headline)
                                HStack(spacing: 6) {
                                    if let muscle = item.muscle { MuscleChip(muscle: muscle) }
                                    Text("\(item.points.count) \(item.points.count == 1 ? "session" : "sessions")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(formatWeight(item.latest.rounded())) \(unit.rawValue)")
                                    .font(.headline.monospacedDigit())
                                if item.points.count > 1 {
                                    Text(item.change >= 0 ? "+\(formatWeight(item.change.rounded()))" : formatWeight(item.change.rounded()))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(item.change >= 0 ? Color.green : Color.orange)
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("Estimated 1RM")
            } footer: {
                Text("Estimated from your best set each session, counting the reps you left in reserve.")
            }
        }
    }

    // MARK: History

    @ViewBuilder
    private var historyList: some View {
        Section {
            StatsRow(history: history)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        }
        Section("History") {
            if history.isEmpty {
                ContentUnavailableView("No workouts yet",
                                       systemImage: "dumbbell",
                                       description: Text("Finished sessions show up here."))
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
}

struct StrengthSeries: Identifiable, Hashable {
    struct Point: Identifiable, Hashable {
        let id = UUID()
        let date: Date
        let value: Double
        let bestSet: String
    }

    let name: String
    let muscle: Muscle?
    let points: [Point]

    var id: String { name }
    var latest: Double { points.last?.value ?? 0 }
    var change: Double { latest - (points.first?.value ?? 0) }

    /// One point per finished session per exercise, most recently trained exercise first.
    static func all(from workouts: [Workout]) -> [StrengthSeries] {
        var byName: [String: (muscle: Muscle?, points: [Point])] = [:]
        for workout in workouts.sorted(by: { $0.startDate < $1.startDate }) {
            for exercise in workout.exercises {
                guard let best = exercise.strongestSet else { continue }
                let point = Point(date: workout.startDate, value: best.oneRepMax,
                                  bestSet: "\(formatWeight(best.entry.weight)) × \(best.entry.reps)")
                byName[exercise.name, default: (exercise.muscle, [])].points.append(point)
            }
        }
        return byName
            .map { StrengthSeries(name: $0.key, muscle: $0.value.muscle, points: $0.value.points) }
            .sorted { ($0.points.last?.date ?? .distantPast) > ($1.points.last?.date ?? .distantPast) }
    }
}

struct VolumeChart: View {
    let volumes: [MuscleVolume]

    var body: some View {
        Chart {
            ForEach(volumes) { volume in
                let name = volume.muscle.displayName
                let landmarks = volume.muscle.landmarks
                RuleMark(xStart: .value("Productive from", landmarks.mav.lowerBound),
                         xEnd: .value("Productive to", landmarks.mav.upperBound),
                         y: .value("Muscle", name))
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .foregroundStyle(Color.green)
                    .offset(y: 10)
                BarMark(xStart: .value("Start", 0), xEnd: .value("Planned", volume.planned),
                        y: .value("Muscle", name), height: .fixed(12))
                    .foregroundStyle(Color.accentColor.opacity(0.35))
                    .cornerRadius(3)
                    .annotation(position: .top, alignment: .leading, spacing: 4) {
                        Text("\(name)  \(volume.done)/\(volume.planned)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    }
                BarMark(xStart: .value("Start", 0), xEnd: .value("Done", volume.done),
                        y: .value("Muscle", name), height: .fixed(12))
                    .foregroundStyle(Color.accentColor)
                    .cornerRadius(3)
                RectangleMark(x: .value("Minimum effective", landmarks.mev), y: .value("Muscle", name),
                              width: 2, height: .fixed(14))
                    .foregroundStyle(Color.primary.opacity(0.7))
                RectangleMark(x: .value("Maximum recoverable", landmarks.mrv), y: .value("Muscle", name),
                              width: 2, height: .fixed(14))
                    .foregroundStyle(Color.red)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: 5)) {
                AxisGridLine().foregroundStyle(Color(.separator))
                AxisValueLabel()
            }
        }
        .chartYAxis(.hidden)
        .chartXAxisLabel("Sets in the week")
        .frame(height: CGFloat(volumes.count) * 44 + 40)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(volumes.map { "\($0.muscle.displayName) \($0.done) of \($0.planned) sets" }.joined(separator: ", "))
    }
}

struct ExerciseTrendView: View {
    let series: StrengthSeries
    let unit: WeightUnit

    @State private var selectedDate: Date?

    private var selected: StrengthSeries.Point? {
        guard let selectedDate else { return nil }
        return series.points.min { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    StatTile(title: "Current (\(unit.rawValue))", value: formatWeight(series.latest.rounded()), icon: "scalemass.fill")
                    StatTile(title: "Since first", value: (series.change >= 0 ? "+" : "") + formatWeight(series.change.rounded()),
                             icon: "chart.line.uptrend.xyaxis")
                    StatTile(title: "Sessions", value: "\(series.points.count)", icon: "calendar")
                }
                .fixedSize(horizontal: false, vertical: true)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                Chart {
                    ForEach(series.points) { point in
                        LineMark(x: .value("Date", point.date), y: .value("Estimated 1RM", point.value))
                            .interpolationMethod(.monotone)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .foregroundStyle(Color.accentColor)
                        PointMark(x: .value("Date", point.date), y: .value("Estimated 1RM", point.value))
                            .symbolSize(60)
                            .foregroundStyle(Color.accentColor)
                    }
                    if let selected {
                        RuleMark(x: .value("Selected", selected.date))
                            .foregroundStyle(Color.secondary.opacity(0.5))
                            .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                                VStack(spacing: 2) {
                                    Text("\(formatWeight(selected.value.rounded())) \(unit.rawValue)").font(.caption.bold())
                                    Text(selected.bestSet).font(.caption2).foregroundStyle(.secondary)
                                }
                                .padding(6)
                                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                            }
                    }
                }
                .chartXSelection(value: $selectedDate)
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) {
                        AxisGridLine().foregroundStyle(Color(.separator))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .frame(height: 240)
                .padding(.top, 36)
                .padding(.bottom, 8)
            } header: {
                Text("Estimated 1RM over time")
            } footer: {
                Text("Touch and drag the chart to read a session.")
            }

            Section("Sessions") {
                ForEach(series.points.reversed()) { point in
                    HStack {
                        Text(point.date, format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(point.bestSet).monospacedDigit()
                        Text("\(formatWeight(point.value.rounded()))")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 52, alignment: .trailing)
                    }
                }
            }
        }
        .navigationTitle(series.name)
        .navigationBarTitleDisplayMode(.inline)
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
                if let meso = workout.mesocycle, let week = workout.week {
                    Label("\(meso.name) · \(workout.phase == .deload ? "Deload" : "W\(week + 1)")", systemImage: "calendar")
                        .lineLimit(1)
                }
                Label(formatDuration(workout.duration), systemImage: "clock")
                Label("\(workout.completedSets) \(workout.completedSets == 1 ? "set" : "sets")", systemImage: "checkmark.circle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            let names = workout.sortedExercises.filter { $0.sets.contains(where: \.isDone) }.map(\.name)
            if !names.isEmpty {
                Text(names.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

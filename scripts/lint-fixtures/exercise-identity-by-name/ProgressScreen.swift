import SwiftUI
import SwiftData
import Charts
import FFiveCore

struct ProgressScreen: View {
    private enum Pane: String, CaseIterable, Identifiable {
        case volume = "Volume", strength = "Strength", history = "History"
        var id: Self { self }
    }

    @Environment(Store.self) private var store
    @Query(sort: \Mesocycle.startDate, order: .reverse) private var mesos: [Mesocycle]
    @Query(Workout.history) private var history: [Workout]
    private var unit: WeightUnit { store.settings.weightUnit }

    @State private var pane: Pane = DemoLaunch.route == .strength ? .strength : .volume
    @State private var demoSeries: StrengthSeries?
    @State private var selectedMeso: PersistentIdentifier?
    @State private var selectedWeek: Int?

    var body: some View {
        VStack(spacing: 0) {
            SegmentedButtons(options: Pane.allCases, selection: $pane, label: \.rawValue)
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 12)
            List {
                switch pane {
                case .volume: volume
                case .strength: strength
                case .history: historyList
                }
            }
            .themedList()
        }
        .background(Theme.surface)
        .navigationTitle("Progress")
        .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
        .navigationDestination(for: StrengthSeries.self) { ExerciseTrendView(series: $0, unit: unit) }
        .navigationDestination(item: $demoSeries) { ExerciseTrendView(series: $0, unit: unit) }
        .task {
            if DemoLaunch.take(.strength) {
                demoSeries = StrengthSeries.all(from: history).max { $0.points.count < $1.points.count }
            }
        }
    }

    private func heading(_ text: String) -> some View {
        SectionHeading(text: text)
            .themedRow(vertical: 8)
            .listRowSeparator(.hidden)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(Theme.caption)
            .foregroundStyle(Theme.secondary)
            .themedRow()
            .listRowSeparator(.hidden)
    }

    private func empty(_ title: String, systemImage: String, description: String) -> some View {
        ContentUnavailableView(title, systemImage: systemImage, description: Text(description))
            .themedRow()
            .listRowSeparator(.hidden)
    }


    @ViewBuilder
    private var volume: some View {
        if let meso = mesos.first(where: { $0.persistentModelID == selectedMeso }) ?? mesos.first(where: { $0.finishedDate == nil }) ?? mesos.first {
            let week = min(selectedWeek ?? meso.nextUp?.week ?? meso.accumulationWeeks, meso.accumulationWeeks)
            let volumes = store.weeklyVolume(meso, week: week)
            heading("Sets per muscle · \(meso.phase(week: week) == .deload ? "Deload" : "Week \(week + 1)")")
            VStack(alignment: .leading, spacing: 14) {
                if mesos.count > 1 {
                    HStack {
                        Text("Mesocycle").font(Theme.detail).foregroundStyle(Theme.secondary)
                        Spacer()
                        Picker("Mesocycle", selection: Binding(get: { meso.persistentModelID }, set: { selectedMeso = $0; selectedWeek = nil })) {
                            ForEach(mesos) { Text($0.name).tag($0.persistentModelID) }
                        }
                        .pickerStyle(.menu)
                        .tint(Theme.text)
                    }
                }
                SegmentedButtons(options: Array(0..<meso.totalWeeks),
                                 selection: Binding(get: { week }, set: { selectedWeek = $0 }),
                                 label: { $0 == meso.accumulationWeeks ? "DL" : "W\($0 + 1)" })
                VolumeChart(volumes: volumes)
                VolumeLegend(includesMaximum: true)
            }
            .themedRow(vertical: 4)
            .listRowSeparator(.hidden)
            note("Aim to finish most weeks inside the green range. The red tick is the most a muscle usually recovers from; feedback keeps you below it.")
        } else {
            empty("No mesocycle yet", systemImage: "chart.bar.xaxis",
                  description: "Plan a mesocycle on the Train tab to see weekly sets against each muscle's landmarks.")
        }
    }


    @ViewBuilder
    private var strength: some View {
        let series = StrengthSeries.all(from: history)
        if series.isEmpty {
            empty("No loaded sets yet", systemImage: "chart.line.uptrend.xyaxis",
                  description: "Finish a session with weighted sets to start tracking estimated 1RM.")
        } else {
            heading("Estimated 1RM")
            ForEach(series) { item in
                NavigationLink(value: item) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(Theme.body)
                                .foregroundStyle(Theme.text)
                            HStack(spacing: 4) {
                                if let muscle = item.muscle {
                                    MuscleDotLabel(muscle: muscle)
                                    Text(verbatim: "\u{2022}").accessibilityHidden(true)
                                }
                                Text("\(item.points.count) \(item.points.count == 1 ? "session" : "sessions")")
                            }
                            .font(Theme.caption)
                            .foregroundStyle(Theme.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(formatWeight(item.latest.rounded())) \(unit.rawValue)")
                                .font(Theme.body.weight(.semibold).monospacedDigit())
                                .foregroundStyle(Theme.text)
                            if item.points.count > 1 {
                                Text(item.change >= 0 ? "+\(formatWeight(item.change.rounded()))" : formatWeight(item.change.rounded()))
                                    .font(Theme.caption.monospacedDigit())
                                    .foregroundStyle(item.change >= 0 ? Theme.success : Theme.danger)
                            }
                        }
                    }
                }
                .themedRow()
            }
            note("Estimated from your best set each session, counting the reps you left in reserve.")
        }
    }


    @ViewBuilder
    private var historyList: some View {
        HistoryStats(history: history)
            .themedRow(vertical: 4)
            .listRowSeparator(.hidden)
        heading("History")
            .padding(.top, 8)
        if history.isEmpty {
            empty("No workouts yet", systemImage: "dumbbell", description: "Finished sessions show up here.")
        }
        ForEach(history) { workout in
            NavigationLink(value: workout) {
                HistoryRow(workout: workout)
            }
            .themedRow()
        }
        .onDelete { offsets in
            for index in offsets { store.delete(history[index]) }
        }
    }
}

private struct HistoryStats: View {
    let history: [Workout]

    var body: some View {
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let thisWeek = history.filter { $0.startDate >= weekStart }
        HStack(spacing: 8) {
            StatTile(title: "This Week", value: "\(thisWeek.count)", icon: "flame")
            StatTile(title: "Time", value: formatDuration(thisWeek.reduce(0) { $0 + $1.duration }), icon: "clock")
            StatTile(title: "All Time", value: "\(history.count)", icon: "trophy")
        }
        .fixedSize(horizontal: false, vertical: true)
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
                    .foregroundStyle(Theme.success)
                    .offset(y: 10)
                BarMark(xStart: .value("Start", 0), xEnd: .value("Planned", volume.planned),
                        y: .value("Muscle", name), height: .fixed(12))
                    .foregroundStyle(Theme.infoFill)
                    .cornerRadius(2)
                    .annotation(position: .top, alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(name).foregroundStyle(Theme.text)
                            Text("\(volume.done)/\(volume.planned)").foregroundStyle(Theme.secondary).monospacedDigit()
                        }
                        .font(Theme.caption)
                        .fixedSize()
                    }
                BarMark(xStart: .value("Start", 0), xEnd: .value("Done", volume.done),
                        y: .value("Muscle", name), height: .fixed(12))
                    .foregroundStyle(Theme.infoText)
                    .cornerRadius(2)
                RectangleMark(x: .value("Minimum effective", landmarks.mev), y: .value("Muscle", name),
                              width: 2, height: .fixed(14))
                    .foregroundStyle(Theme.text.opacity(0.7))
                RectangleMark(x: .value("Maximum recoverable", landmarks.mrv), y: .value("Muscle", name),
                              width: 2, height: .fixed(14))
                    .foregroundStyle(Theme.danger)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: 5)) {
                AxisGridLine().foregroundStyle(Theme.hairline)
                AxisValueLabel().foregroundStyle(Theme.secondary)
            }
        }
        .chartYAxis(.hidden)
        .chartXAxisLabel {
            Text("Sets in the week").font(Theme.caption).foregroundStyle(Theme.secondary)
        }
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
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    StatTile(title: "Current (\(unit.rawValue))", value: formatWeight(series.latest.rounded()), icon: "scalemass")
                    StatTile(title: "Since first", value: (series.change >= 0 ? "+" : "") + formatWeight(series.change.rounded()),
                             icon: "chart.line.uptrend.xyaxis")
                    StatTile(title: "Sessions", value: "\(series.points.count)", icon: "calendar")
                }
                .fixedSize(horizontal: false, vertical: true)

                SectionHeading(text: "Estimated 1RM over time")
                    .padding(.top, 12)
                chart
                Text("Touch and drag the chart to read a session.")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondary)

                SectionHeading(text: "Sessions")
                    .padding(.top, 12)
                sessions
            }
            .padding(Theme.gutter)
        }
        .background(Theme.surface)
        .navigationTitle(series.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var chart: some View {
        Chart {
            ForEach(series.points) { point in
                LineMark(x: .value("Date", point.date), y: .value("Estimated 1RM", point.value))
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .foregroundStyle(Theme.infoText)
                PointMark(x: .value("Date", point.date), y: .value("Estimated 1RM", point.value))
                    .symbolSize(60)
                    .foregroundStyle(Theme.infoText)
            }
            if let selected {
                RuleMark(x: .value("Selected", selected.date))
                    .foregroundStyle(Theme.secondary)
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack(spacing: 2) {
                            Text("\(formatWeight(selected.value.rounded())) \(unit.rawValue)")
                                .font(Theme.caption.bold())
                                .foregroundStyle(Theme.text)
                            Text(selected.bestSet).font(.system(size: 11)).foregroundStyle(Theme.secondary)
                        }
                        .padding(6)
                        .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                    }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) {
                AxisGridLine().foregroundStyle(Theme.hairline)
                AxisValueLabel(format: .dateTime.month(.abbreviated).day()).foregroundStyle(Theme.secondary)
            }
        }
        .chartYAxis {
            AxisMarks {
                AxisGridLine().foregroundStyle(Theme.hairline)
                AxisValueLabel().foregroundStyle(Theme.secondary)
            }
        }
        .frame(height: 240)
        .padding(.top, 36)
    }

    private var sessions: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Date")
                Spacer()
                Text("Best set")
                Text("e1RM").frame(width: 60, alignment: .trailing)
            }
            .font(Theme.columnHeader)
            .textCase(.uppercase)
            .foregroundStyle(Theme.secondary)
            .padding(.bottom, 8)
            .accessibilityHidden(true)
            ForEach(series.points.reversed()) { point in
                Rectangle().fill(Theme.hairline).frame(height: 1)
                HStack {
                    Text(point.date, format: .dateTime.month(.abbreviated).day())
                        .foregroundStyle(Theme.secondary)
                    Spacer()
                    Text(point.bestSet).foregroundStyle(Theme.text)
                    Text("\(formatWeight(point.value.rounded()))")
                        .foregroundStyle(Theme.secondary)
                        .frame(width: 60, alignment: .trailing)
                }
                .font(Theme.body.monospacedDigit())
                .frame(minHeight: 44)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

struct HistoryRow: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(workout.name)
                    .font(Theme.body.weight(.semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text(workout.startDate, format: .dateTime.month(.abbreviated).day())
                    .font(Theme.detail)
                    .foregroundStyle(Theme.secondary)
            }
            HStack(spacing: 12) {
                if let meso = workout.mesocycle, let week = workout.week {
                    meta("\(meso.name) · \(workout.phase == .deload ? "Deload" : "W\(week + 1)")", systemImage: "calendar")
                        .lineLimit(1)
                }
                meta(formatDuration(workout.duration), systemImage: "clock")
                meta("\(workout.completedSets) \(workout.completedSets == 1 ? "set" : "sets")", systemImage: "checkmark.circle")
            }
            .font(Theme.caption)
            .foregroundStyle(Theme.secondary)
            let names = workout.sortedExercises.filter { $0.sets.contains(where: \.isDone) }.map(\.name)
            if !names.isEmpty {
                Text(names.joined(separator: " · "))
                    .font(Theme.caption)
                    .foregroundStyle(Theme.text.opacity(0.35))
                    .lineLimit(1)
            }
        }
    }

    private func meta(_ text: String, systemImage: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
            Text(text)
        }
    }
}

#Preview {
    NavigationStack { ProgressScreen() }
        .modelContainer(AppStore.makeContainer(inMemory: true))
        .preferredColorScheme(.dark)
}

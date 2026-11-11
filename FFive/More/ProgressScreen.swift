import Charts
import FFiveCore
import SwiftData
import SwiftUI

struct ProgressScreen: View {
    private enum Pane: String, CaseIterable, Identifiable {
        case volume = "Volume"
        case strength = "Strength"
        case history = "History"
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
    @State private var deleting: Workout?

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
        .navigationDestination(for: StrengthSeries.self) { ExerciseTrendView(series: $0, unit: unit) }
        .navigationDestination(item: $demoSeries) { ExerciseTrendView(series: $0, unit: unit) }
        .confirmationDialog(
            "Delete this workout?",
            isPresented: $deleting.isPresent(),
            titleVisibility: .visible, presenting: deleting
        ) { workout in
            Button("Delete Workout", role: .destructive) { withAnimation(.snappy) { store.delete(workout) } }
                .a11y(.dialogDeleteWorkout)
        } message: { workout in
            Text("\(workout.name) leaves History and Progress.")
        }
        .task {
            if DemoLaunch.take(.strength) {
                demoSeries = store.strengthSeries().max { $0.points.count < $1.points.count }
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(Theme.caption)
            .foregroundStyle(Theme.secondary)
            .themedRow()
            .listRowSeparator(.hidden)
    }

    private func empty(_ title: String, systemImage: String, description: String) -> some View {
        EmptyState(title, systemImage: systemImage, message: description)
            .themedRow()
            .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private var volume: some View {
        if let meso = mesos.first(where: { $0.persistentModelID == selectedMeso }) ?? mesos.first(where: \.isActive)
            ?? mesos.first
        {
            let week = min(selectedWeek ?? meso.nextUp?.week ?? meso.accumulationWeeks, meso.accumulationWeeks)
            let volumes = store.weeklyVolume(meso, week: week)
            SectionHeading(
                text: "Sets per Muscle · \(meso.phase(week: week).longLabel(week: week))"
            )
            .themedRow(vertical: 0)
            .listRowSeparator(.hidden)
            VStack(alignment: .leading, spacing: 14) {
                if mesos.count > 1 {
                    HStack {
                        Text("Mesocycle").font(Theme.detail).foregroundStyle(Theme.secondary)
                        Spacer()
                        Picker(
                            "Mesocycle",
                            selection: Binding(
                                get: { meso.persistentModelID },
                                set: {
                                    selectedMeso = $0
                                    selectedWeek = nil
                                })
                        ) {
                            ForEach(mesos) { Text($0.name).tag($0.persistentModelID) }
                        }
                        .pickerStyle(.menu)
                        .tint(Theme.text)
                    }
                }
                SegmentedButtons(
                    options: Array(0..<meso.totalWeeks),
                    selection: Binding(get: { week }, set: { selectedWeek = $0 }),
                    label: { meso.phase(week: $0).shortLabel(week: $0) })
                VolumeChart(volumes: volumes)
            }
            .themedRow(vertical: 4)
            .listRowSeparator(.hidden)
            note(
                "Aim to finish most weeks inside the green range. The red tick is the most a muscle usually recovers from; feedback keeps you below it."
            )
        } else {
            empty(
                "No mesocycles yet", systemImage: Symbol.progress,
                description: "Plan a mesocycle on the Workout tab to see weekly sets against each muscle's landmarks.")
        }
    }

    @ViewBuilder
    private var strength: some View {
        let series = store.strengthSeries()
        if series.isEmpty {
            empty(
                "No loaded sets yet", systemImage: "chart.line.uptrend.xyaxis",
                description: "Finish a session with weighted sets to start tracking estimated 1RM.")
        } else {
            SectionHeading(text: "Estimated 1RM")
                .themedRow(vertical: 0)
                .listRowSeparator(.hidden)
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
                                .font(Theme.rowTitle.monospacedDigit())
                                .foregroundStyle(Theme.text)
                            if item.points.count > 1 {
                                Text(
                                    item.change >= 0
                                        ? "+\(formatWeight(item.change.rounded()))"
                                        : formatWeight(item.change.rounded())
                                )
                                .font(Theme.caption.monospacedDigit())
                                .foregroundStyle(item.change >= 0 ? Theme.success : Theme.danger)
                            }
                        }
                    }
                }
                .themedRow()
                .a11y(.strengthRow, key: item.name)
            }
            note("Estimated from your best set each session, counting the reps you left in reserve.")
        }
    }

    @ViewBuilder
    private var historyList: some View {
        StatsRow(stats: store.weekStats())
            .themedRow(vertical: 4)
            .listRowSeparator(.hidden)
        SectionHeading(text: "History")
            .themedRow(vertical: 0)
            .listRowSeparator(.hidden)
        if history.isEmpty {
            empty("No workouts yet", systemImage: "dumbbell", description: "Finished sessions show up here.")
        }
        ForEach(history) { workout in
            NavigationLink(value: workout) {
                HistoryRow(workout: workout)
            }
            .themedRow()
            .a11y(.historyRow, key: workout.name)
        }
        .onDelete { offsets in
            deleting = offsets.first.map { history[$0] }
        }
    }
}

struct ExerciseTrendView: View {
    let series: StrengthSeries
    let unit: WeightUnit

    @State private var selectedDate: Date?

    private var selected: StrengthSeries.Point? {
        guard let selectedDate else { return nil }
        return series.points.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    StatTile(
                        title: "Current (\(unit.rawValue))", value: formatWeight(series.latest.rounded()),
                        icon: "scalemass")
                    StatTile(
                        title: "Since First",
                        value: (series.change >= 0 ? "+" : "") + formatWeight(series.change.rounded()),
                        icon: "chart.line.uptrend.xyaxis")
                    StatTile(title: "Sessions", value: "\(series.points.count)", icon: "calendar")
                }
                .fixedSize(horizontal: false, vertical: true)

                SectionHeading(text: "Estimated 1RM Over Time")
                chart
                Text("Touch and drag the chart to read a session.")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondary)
                    .padding(.top, 8)

                SectionHeading(text: "Sessions")
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
                            Text(selected.bestSet).font(Theme.caption).foregroundStyle(Theme.secondary)
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
                Text("Best Set")
                Text("Estimated 1RM").frame(width: 130, alignment: .trailing)
            }
            .font(Theme.columnHeader)
            .textCase(.uppercase)
            .foregroundStyle(Theme.secondary)
            .padding(.bottom, 8)
            .accessibilityHidden(true)
            ForEach(series.points.reversed()) { point in
                Hairline()
                HStack {
                    Text(point.date, format: .dateTime.month(.abbreviated).day())
                        .foregroundStyle(Theme.secondary)
                    Spacer()
                    Text(point.bestSet).foregroundStyle(Theme.text)
                    Text("\(formatWeight(point.value.rounded()))")
                        .foregroundStyle(Theme.secondary)
                        .frame(width: 130, alignment: .trailing)
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
                    .font(Theme.rowTitle)
                    .foregroundStyle(Theme.text)
                Spacer()
                Text(workout.startDate, format: .sessionDay)
                    .font(Theme.detail)
                    .foregroundStyle(Theme.secondary)
            }
            HStack(spacing: 12) {
                if let meso = workout.mesocycle, let week = workout.week, let phase = workout.phase {
                    meta(
                        "\(meso.name) · \(phase.longLabel(week: week))",
                        systemImage: "calendar"
                    )
                    .lineLimit(1)
                }
                meta(formatDuration(workout.duration), systemImage: "clock")
                meta(
                    "\(workout.completedSets) \(workout.completedSets == 1 ? "set" : "sets")",
                    systemImage: "checkmark.circle")
            }
            .font(Theme.caption)
            .foregroundStyle(Theme.secondary)
            let names = workout.sortedExercises.filter { $0.sets.contains(where: \.isDone) }.map(\.name)
            if !names.isEmpty {
                Text(names.joined(separator: " · "))
                    .font(Theme.caption)
                    .foregroundStyle(Theme.text.opacity(Theme.dimmed))
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
    let store = Store(inMemory: true)
    return NavigationStack { ProgressScreen() }
        .environment(store)
        .modelContainer(store.container)
        .preferredColorScheme(.dark)
}

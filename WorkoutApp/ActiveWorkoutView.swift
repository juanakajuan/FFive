import SwiftUI
import SwiftData

enum SessionEnd { case finish, discard }

struct ActiveWorkoutView: View {
    @Bindable var workout: Workout
    var onEnd: (SessionEnd) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("weightUnit") private var unit: WeightUnit = .lb
    @AppStorage("restSeconds") private var restSeconds = 90

    @State private var picker: PickerRequest?
    @State private var confirmDiscard = false
    @State private var restEnd: Date?
    @State private var setsCompleted = 0
    @State private var restsFinished = 0

    private enum PickerRequest: Identifiable {
        case add
        case swap(Exercise)

        var id: String {
            switch self {
            case .add: "add"
            case .swap(let exercise): "swap-\(ObjectIdentifier(exercise))"
            }
        }
    }

    var body: some View {
        let exercises = workout.sortedExercises
        let pendingSoreness = MesoPlanner.pendingSoreness(for: workout)
        NavigationStack {
            List {
                Section {
                    TextField("Workout name", text: $workout.name)
                        .font(.title2.bold())
                    HStack {
                        Label {
                            Text(workout.startDate, style: .timer).monospacedDigit()
                        } icon: {
                            Image(systemName: "timer").foregroundStyle(.tint)
                        }
                        Spacer()
                        if let week = workout.week, let phase = workout.phase {
                            Text(phase == .deload ? "Deload week" : "Week \(week + 1)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            PhaseBadge(phase: phase)
                        } else {
                            Text("\(workout.completedSets) \(workout.completedSets == 1 ? "set" : "sets") done")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                    let muscle = exercise.muscle
                    if let muscle, let record = pendingSoreness[muscle],
                       exercises.firstIndex(where: { $0.muscle == muscle }) == index {
                        Section {
                            SorenessCard(muscle: muscle, record: record) { soreness in
                                withAnimation {
                                    MesoPlanner.recordSoreness(soreness, on: record, during: workout, unit: unit, in: context)
                                }
                            }
                        }
                    }

                    ExerciseSection(exercise: exercise,
                                    unit: unit,
                                    phase: workout.phase,
                                    onSetCompleted: startRest,
                                    onSwap: workout.mesocycle == nil ? nil : { picker = .swap(exercise) }) {
                        workout.exercises.removeAll { $0 === exercise }
                        context.delete(exercise)
                    }

                    if let muscle, workout.mesocycle != nil,
                       exercises.lastIndex(where: { $0.muscle == muscle }) == index,
                       !exercise.sets.isEmpty, exercise.sets.allSatisfy(\.isDone) {
                        Section {
                            FeedbackCard(muscle: muscle, feedback: workout.feedbackRecord(for: muscle)?.value ?? MuscleFeedback()) { change in
                                workout.updateFeedback(for: muscle, change)
                            }
                        }
                    }
                }

                Section {
                    Button { picker = .add } label: {
                        Label("Add Exercise", systemImage: "plus.circle.fill").font(.headline)
                    }
                }

                Section {
                    Button("Discard Workout", role: .destructive) { confirmDiscard = true }
                }
            }
            .navigationTitle(workout.mesocycle?.name ?? "Workout")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .animation(.snappy, value: exercises.map { $0.sets.allSatisfy(\.isDone) })
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") { onEnd(.finish) }
                        .bold()
                        .disabled(workout.completedSets == 0)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                        to: nil, from: nil, for: nil)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let end = restEnd {
                    RestBar(end: end,
                            onAdd: { restEnd = end.addingTimeInterval(15) },
                            onSkip: { restEnd = nil })
                }
            }
            .animation(.snappy, value: restEnd)
            .task(id: restEnd) {
                guard let end = restEnd else { return }
                try? await Task.sleep(for: .seconds(max(0, end.timeIntervalSinceNow)))
                guard !Task.isCancelled else { return }
                restEnd = nil
                restsFinished += 1
            }
            .sensoryFeedback(.success, trigger: setsCompleted)
            .sensoryFeedback(.warning, trigger: restsFinished)
            .sheet(item: $picker) { request in
                switch request {
                case .add:
                    ExercisePickerView { name, muscle in addExercise(name, muscle: muscle) }
                case .swap(let exercise):
                    ExercisePickerView(title: "Swap \(exercise.name)", muscle: exercise.muscle) { name, muscle in
                        MesoPlanner.swap(exercise, to: name, muscle: muscle, unit: unit, in: context)
                    }
                }
            }
            .confirmationDialog("Discard this workout?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard", role: .destructive) { onEnd(.discard) }
            }
        }
    }

    private func startRest() {
        setsCompleted += 1
        restEnd = .now.addingTimeInterval(TimeInterval(restSeconds))
    }

    private func addExercise(_ name: String, muscle: Muscle) {
        if workout.mesocycle != nil {
            MesoPlanner.addExercise(named: name, muscle: muscle, to: workout, unit: unit, in: context)
            return
        }
        let exercise = Exercise(name: name, order: (workout.exercises.map(\.order).max() ?? -1) + 1, muscle: muscle)
        workout.exercises.append(exercise)

        // Pre-fill with what you did last time for this exercise, or a single empty set.
        let previous = previousSets(for: name)
        if previous.isEmpty {
            exercise.sets.append(SetEntry(reps: 10, weight: 0, order: 0))
        } else {
            for (i, set) in previous.enumerated() {
                exercise.sets.append(SetEntry(reps: set.reps, weight: set.weight, order: i))
            }
        }
    }

    private func previousSets(for name: String) -> [SetEntry] {
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == name })
        let matches = (try? context.fetch(descriptor)) ?? []
        let last = matches
            .filter { $0.workout?.endDate != nil }
            .max { ($0.workout?.startDate ?? .distantPast) < ($1.workout?.startDate ?? .distantPast) }
        return last?.sortedSets.filter(\.isDone) ?? []
    }
}

struct ExerciseSection: View {
    let exercise: Exercise
    let unit: WeightUnit
    let phase: WeekPhase?
    var onSetCompleted: () -> Void
    var onSwap: (() -> Void)?
    var onRemove: () -> Void

    @Environment(\.modelContext) private var context
    @State private var showingCue = false

    var body: some View {
        Section {
            if showingCue, let info = exercise.info {
                VStack(alignment: .leading, spacing: 4) {
                    Text(info.cue)
                    Text("\(info.equipment.displayName) · \(info.repRange.lowerBound)–\(info.repRange.upperBound) reps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
                .listRowBackground(Color.accentColor.opacity(0.1))
            }

            ForEach(Array(exercise.sortedSets.enumerated()), id: \.element.id) { index, set in
                SetRow(set: set, number: index + 1, unit: unit, target: phase.flatMap { targetText(set, $0) },
                       onCompleted: onSetCompleted)
                    .listRowBackground(set.isDone ? Color.green.opacity(0.15) : nil)
            }
            .onDelete { offsets in
                let sorted = exercise.sortedSets
                for index in offsets {
                    let set = sorted[index]
                    exercise.sets.removeAll { $0 === set }
                    context.delete(set)
                }
            }

            Button(action: addSet) {
                Label("Add Set", systemImage: "plus")
            }
        } header: {
            HStack(spacing: 8) {
                Text(exercise.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .textCase(nil)
                    .lineLimit(1)
                if let muscle = exercise.muscle {
                    MuscleChip(muscle: muscle).textCase(nil)
                }
                Spacer()
                if exercise.info != nil {
                    Button {
                        withAnimation(.snappy) { showingCue.toggle() }
                    } label: {
                        Image(systemName: showingCue ? "info.circle.fill" : "info.circle").font(.body)
                    }
                    .accessibilityLabel("Technique cue")
                }
                Menu {
                    if let onSwap {
                        Button("Swap Exercise", systemImage: "arrow.triangle.2.circlepath", action: onSwap)
                            .disabled(exercise.sets.contains(where: \.isDone))
                    }
                    Button("Remove Exercise", systemImage: "trash", role: .destructive, action: onRemove)
                } label: {
                    Image(systemName: "ellipsis.circle").font(.body)
                }
            }
        }
    }

    private func targetText(_ set: SetEntry, _ phase: WeekPhase) -> String? {
        guard let weight = set.targetWeight else {
            let range = exercise.repRange
            let effort = phase.rir.map { "at \($0) RIR" } ?? "kept light"
            return "Calibrate · \(range.lowerBound)–\(range.upperBound) reps \(effort)"
        }
        guard let reps = set.targetReps else { return "Target \(formatWeight(weight)) \(unit.rawValue)" }
        return weight == 0 ? "Target \(reps) reps" : "Target \(formatWeight(weight)) × \(reps)"
    }

    private func addSet() {
        let last = exercise.sortedSets.last
        let set = SetEntry(reps: last?.reps ?? 10,
                           weight: last?.weight ?? 0,
                           order: (last?.order ?? -1) + 1)
        set.targetWeight = last?.targetWeight
        set.targetReps = last?.targetReps
        exercise.sets.append(set)
    }
}

struct SetRow: View {
    @Bindable var set: SetEntry
    let number: Int
    let unit: WeightUnit
    let target: String?
    var onCompleted: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 10) {
                    TextField("0", value: $set.weight, format: .number)
                        .keyboardType(.decimalPad)
                        .modifier(NumberFieldStyle())
                    Text(unit.rawValue).font(.caption).foregroundStyle(.secondary)

                    TextField("0", value: $set.reps, format: .number)
                        .keyboardType(.numberPad)
                        .modifier(NumberFieldStyle())
                    Text("reps").font(.caption).foregroundStyle(.secondary)
                }
                if let target {
                    Text(target)
                        .font(.caption)
                        .foregroundStyle(set.targetWeight == nil ? Color.accentColor : Color.secondary)
                }
            }

            Spacer(minLength: 0)

            Button {
                set.isDone.toggle()
                if set.isDone { onCompleted() }
            } label: {
                Image(systemName: set.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(set.isDone ? Color.green : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.borderless)
        }
    }
}

struct SorenessCard: View {
    let muscle: Muscle
    let record: MuscleFeedbackRecord
    var onAnswer: (Soreness) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Label("How did your \(muscle.displayName.lowercased()) recover?", systemImage: "bandage")
                    .font(.headline)
                if let previous = record.workout {
                    Text("Since \(previous.name), \(previous.startDate.formatted(.dateTime.weekday(.wide)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            ChipPicker(title: "Soreness after that session", options: Soreness.allCases, columns: 2,
                       label: \.label, selection: nil) { if let soreness = $0 { onAnswer(soreness) } }
        }
        .padding(.vertical, 6)
    }
}

struct FeedbackCard: View {
    let muscle: Muscle
    let feedback: MuscleFeedback
    var onChange: ((inout MuscleFeedback) -> Void) -> Void

    private var isComplete: Bool { feedback.pump != nil && feedback.workload != nil && feedback.jointPain != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("How did \(muscle.displayName.lowercased()) feel today?", systemImage: "waveform.path.ecg")
                    .font(.headline)
                Spacer()
                if isComplete {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }
            ChipPicker(title: "Pump", options: Pump.allCases, columns: 3, label: \.label, selection: feedback.pump) { value in
                onChange { $0.pump = value }
            }
            ChipPicker(title: "Workload", options: Workload.allCases, columns: 2, label: \.label, selection: feedback.workload) { value in
                onChange { $0.workload = value }
            }
            ChipPicker(title: "Joint pain", options: JointPain.allCases, columns: 4, label: \.label, selection: feedback.jointPain) { value in
                onChange { $0.jointPain = value }
            }
            Text("Next week's sets for \(muscle.displayName.lowercased()) come from these answers and how sore you get.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

struct NumberFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .multilineTextAlignment(.center)
            .monospacedDigit()
            .frame(width: 60)
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct RestBar: View {
    let end: Date
    var onAdd: () -> Void
    var onSkip: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "hourglass").foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 0) {
                Text("Rest").font(.caption).foregroundStyle(.secondary)
                Text(timerInterval: Date.now...max(end, .now), countsDown: true)
                    .font(.title3.bold())
                    .monospacedDigit()
            }
            Spacer()
            Button("+15s", action: onAdd).buttonStyle(.bordered)
            Button("Skip", action: onSkip)
                .buttonStyle(.borderedProminent)
                .foregroundStyle(.black)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

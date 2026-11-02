import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Bindable var workout: Workout
    var onEnd: (HomeView.EndAction) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("weightUnit") private var unit: WeightUnit = .lb
    @AppStorage("restSeconds") private var restSeconds = 90

    @State private var showingPicker = false
    @State private var confirmDiscard = false
    @State private var restEnd: Date?
    @State private var setsCompleted = 0
    @State private var restsFinished = 0

    var body: some View {
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
                        Text("\(workout.completedSets) \(workout.completedSets == 1 ? "set" : "sets") done")
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(workout.sortedExercises) { exercise in
                    ExerciseSection(exercise: exercise, unit: unit, onSetCompleted: startRest) {
                        workout.exercises.removeAll { $0 === exercise }
                        context.delete(exercise)
                    }
                }

                Section {
                    Button { showingPicker = true } label: {
                        Label("Add Exercise", systemImage: "plus.circle.fill").font(.headline)
                    }
                }

                Section {
                    Button("Discard Workout", role: .destructive) { confirmDiscard = true }
                }
            }
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
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
            .sheet(isPresented: $showingPicker) {
                ExercisePickerView(onPick: addExercise)
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
    var onSetCompleted: () -> Void
    var onRemove: () -> Void

    @Environment(\.modelContext) private var context

    var body: some View {
        Section {
            ForEach(Array(exercise.sortedSets.enumerated()), id: \.element.id) { index, set in
                SetRow(set: set, number: index + 1, unit: unit, onCompleted: onSetCompleted)
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
            HStack {
                Text(exercise.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .textCase(nil)
                Spacer()
                Menu {
                    Button("Remove Exercise", systemImage: "trash", role: .destructive, action: onRemove)
                } label: {
                    Image(systemName: "ellipsis.circle").font(.body)
                }
            }
        }
    }

    private func addSet() {
        let last = exercise.sortedSets.last
        let set = SetEntry(reps: last?.reps ?? 10,
                           weight: last?.weight ?? 0,
                           order: (last?.order ?? -1) + 1)
        exercise.sets.append(set)
    }
}

struct SetRow: View {
    @Bindable var set: SetEntry
    let number: Int
    let unit: WeightUnit
    var onCompleted: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .frame(width: 22)

            TextField("0", value: $set.weight, format: .number)
                .keyboardType(.decimalPad)
                .modifier(NumberFieldStyle())
            Text(unit.rawValue).font(.caption).foregroundStyle(.secondary)

            TextField("0", value: $set.reps, format: .number)
                .keyboardType(.numberPad)
                .modifier(NumberFieldStyle())
            Text("reps").font(.caption).foregroundStyle(.secondary)

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

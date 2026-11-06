import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Bindable var workout: Workout
    let activeMeso: Mesocycle?
    let openQuickWorkout: Workout?

    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @AppStorage("weightUnit") private var unit: WeightUnit = .lb

    @State private var picker: PickerRequest?
    @State private var showingSchedule = false
    @State private var confirmDiscard = false
    @State private var confirmEnd = false
    @State private var renameDraft: String?
    @State private var noteDraft: String?
    @State private var setsCompleted = 0

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
        ScrollView {
            LazyVStack(spacing: 16) {
                if let note = workout.note {
                    Callout(text: note, systemImage: "note.text", style: .note)
                        .padding(.horizontal, Theme.gutter)
                        .accessibilityLabel("Workout note: \(note)")
                }
                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                    let muscle = exercise.muscle
                    if let muscle, let record = pendingSoreness[muscle],
                       exercises.firstIndex(where: { $0.muscle == muscle }) == index {
                        SorenessCard(muscle: muscle, record: record) { soreness in
                            withAnimation {
                                MesoPlanner.recordSoreness(soreness, on: record, during: workout, unit: unit, in: context)
                            }
                        }
                    }

                    ExerciseCard(exercise: exercise,
                                 unit: unit,
                                 phase: workout.phase,
                                 onSetCompleted: setCompleted,
                                 onSwap: workout.mesocycle == nil ? nil : { picker = .swap(exercise) }) {
                        workout.exercises.removeAll { $0 === exercise }
                        context.delete(exercise)
                    }

                    if let muscle, workout.mesocycle != nil,
                       exercises.lastIndex(where: { $0.muscle == muscle }) == index,
                       exercise.isLogged {
                        FeedbackCard(muscle: muscle, feedback: workout.feedbackRecord(for: muscle)?.value ?? MuscleFeedback()) { change in
                            workout.updateFeedback(for: muscle, change)
                        }
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if workout.isFullyLogged {
                Button("Finish Workout", action: finish)
                    .buttonStyle(.wideFilled)
                    .padding(.horizontal, Theme.gutter)
                    .padding(.vertical, 12)
                    .background(Theme.page)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: exercises.map(\.isLogged))
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
        .sensoryFeedback(.success, trigger: setsCompleted)
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
        .sheet(isPresented: $showingSchedule) {
            if let activeMeso {
                ScheduleSheet(meso: activeMeso, week: workout.week ?? activeMeso.nextUp?.week ?? activeMeso.accumulationWeeks)
            }
        }
        .confirmationDialog("Discard this workout?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard Workout", role: .destructive, action: discard)
        } message: {
            Text(workout.mesocycle == nil
                 ? "Its exercises and sets are deleted."
                 : "Logged sets for this day are cleared and it starts over from the plan.")
        }
        .confirmationDialog("End this mesocycle?", isPresented: $confirmEnd, titleVisibility: .visible) {
            if let activeMeso {
                Button("End Mesocycle", role: .destructive) { WorkoutTabActions.end(activeMeso, router: router, in: context) }
            }
        } message: {
            Text("Logged sessions stay in Progress. You can plan a new block right after.")
        }
        .alert("Rename Workout", isPresented: Binding(get: { renameDraft != nil }, set: { if !$0 { renameDraft = nil } })) {
            TextField("Workout name", text: Binding(get: { renameDraft ?? "" }, set: { renameDraft = $0 }))
            Button("Save") {
                if let name = renameDraft?.trimmingCharacters(in: .whitespaces), !name.isEmpty { workout.name = name }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Workout Note", isPresented: Binding(get: { noteDraft != nil }, set: { if !$0 { noteDraft = nil } })) {
            TextField("Note", text: Binding(get: { noteDraft ?? "" }, set: { noteDraft = $0 }))
            Button("Save") { workout.setNote(noteDraft ?? "") }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var header: some View {
        WorkoutHeader(title: headerTitle, subtitle: headerSubtitle, progress: workout.setProgress) {
            if activeMeso != nil {
                Button { showingSchedule = true } label: { ActionIcon.calendar }
                    .accessibilityLabel("Schedule")
            }
            Menu {
                menuItems
            } label: {
                ActionIcon.verticalEllipsis
            }
            .accessibilityLabel("Workout menu")
        }
    }

    private var headerTitle: Text {
        guard let key = workout.key, let phase = workout.phase else { return Text("Quick Workout") }
        let lead = phase == .deload ? "Deload" : "Week \(key.week + 1)"
        return Text("\(lead) ") + Text("Day \(key.dayIndex + 1)").foregroundStyle(Theme.secondary)
    }

    private var headerSubtitle: Text {
        if let meso = workout.mesocycle {
            let effort = workout.phase.map { " · \($0.badgeText)" } ?? ""
            return Text("\(workout.name) · \(meso.name)\(effort)")
        }
        return Text("\(workout.name) · ") + Text(workout.startDate, style: .timer).monospacedDigit()
    }

    @ViewBuilder
    private var menuItems: some View {
        Button("Add Exercise", systemImage: "plus") { picker = .add }
        if let meso = workout.mesocycle, let key = workout.key, meso.canSkip(key) {
            Button("Skip Day", systemImage: "forward") { skip(key, of: meso) }
        }
        if activeMeso != nil, openQuickWorkout !== workout {
            Button(openQuickWorkout == nil ? "Quick Workout" : "Resume Quick Workout",
                   systemImage: openQuickWorkout == nil ? "bolt" : "play") {
                WorkoutTabActions.showQuickWorkout(openQuickWorkout, router: router, in: context)
            }
        }
        Button(workout.note == nil ? "Add Note" : "Edit Note", systemImage: "note.text") { noteDraft = workout.note ?? "" }
        if workout.mesocycle == nil {
            Button("Rename", systemImage: "pencil") { renameDraft = workout.name }
        }
        Button("Discard Workout", systemImage: "trash", role: .destructive) { confirmDiscard = true }
        if activeMeso != nil {
            Button("End Mesocycle", systemImage: "flag.checkered", role: .destructive) { confirmEnd = true }
        }
    }

    private func setCompleted() {
        setsCompleted += 1
    }

    private func finish() {
        workout.finish(in: context)
        try? context.save()
        router.focus = nil
    }

    private func discard() {
        workout.mesocycle?.workouts.removeAll { $0 === workout }
        context.delete(workout)
        try? context.save()
    }

    private func skip(_ key: SessionKey, of meso: Mesocycle) {
        withAnimation { meso.skip(key, in: context) }
        try? context.save()
        router.focus = nil
    }

    private func addExercise(_ name: String, muscle: Muscle) {
        if workout.mesocycle != nil {
            MesoPlanner.addExercise(named: name, muscle: muscle, to: workout, unit: unit, in: context)
            return
        }
        let exercise = Exercise(name: name, order: (workout.exercises.map(\.order).max() ?? -1) + 1, muscle: muscle)
        workout.exercises.append(exercise)

        let previous = lastFinishedExercise(named: name, in: context)?.sortedSets.filter(\.isDone) ?? []
        if previous.isEmpty {
            exercise.sets.append(SetEntry(reps: 10, weight: 0, order: 0))
        } else {
            for (i, set) in previous.enumerated() {
                exercise.sets.append(SetEntry(reps: set.reps, weight: set.weight, order: i))
            }
        }
    }
}

@MainActor
func lastFinishedExercise(named name: String, in context: ModelContext) -> Exercise? {
    let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == name })
    return ((try? context.fetch(descriptor)) ?? [])
        .filter { $0.workout?.endDate != nil }
        .max { ($0.workout?.startDate ?? .distantPast) < ($1.workout?.startDate ?? .distantPast) }
}

private enum SetColumns {
    static let menu: CGFloat = 32
    static let field: CGFloat = 93
}

struct ExerciseCard: View {
    let exercise: Exercise
    let unit: WeightUnit
    let phase: WeekPhase?
    var onSetCompleted: () -> Void
    var onSwap: (() -> Void)?
    var onRemove: () -> Void

    @Environment(\.modelContext) private var context
    @Query private var notes: [ExerciseNote]
    @State private var showingCue = false
    @State private var showingHistory = false
    @State private var noteDraft: String?

    init(exercise: Exercise, unit: WeightUnit, phase: WeekPhase?, onSetCompleted: @escaping () -> Void,
         onSwap: (() -> Void)? = nil, onRemove: @escaping () -> Void) {
        self.exercise = exercise
        self.unit = unit
        self.phase = phase
        self.onSetCompleted = onSetCompleted
        self.onSwap = onSwap
        self.onRemove = onRemove
        let name = exercise.name
        _notes = Query(filter: #Predicate<ExerciseNote> { $0.name == name })
    }

    var body: some View {
        let sets = exercise.sortedSets
        let note = notes.first?.text
        VStack(alignment: .leading, spacing: 0) {
            if let muscle = exercise.muscle {
                MuscleTag(muscle: muscle).padding(.horizontal, Theme.gutter)
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(Theme.cardTitle)
                        .foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(exercise.info?.equipment.displayName ?? "Custom")
                        .font(Theme.detail)
                        .foregroundStyle(Theme.secondary)
                }
                Spacer(minLength: 0)
                actions
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 10)

            VStack(spacing: 8) {
                if let note {
                    Callout(text: note, systemImage: "note.text", style: .note)
                        .accessibilityLabel("Note: \(note)")
                }
                if showingCue, let info = exercise.info {
                    Callout(text: "\(info.cue) \(info.repRange.lowerBound)–\(info.repRange.upperBound) reps.",
                            systemImage: "lightbulb.fill")
                }
                if let phase, let set = sets.first(where: { !$0.isDone }) ?? sets.first {
                    Callout(text: targetText(set, phase))
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 10)

            if !sets.isEmpty {
                columnHeaders.padding(.top, 14)
                ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                    if index > 0 { Rectangle().fill(Theme.hairline).frame(height: 1) }
                    SetRow(set: set, number: index + 1, unit: unit, rir: phase?.rir,
                           onCompleted: onSetCompleted, onAdd: addSet) { delete(set) }
                }
            }
        }
        .surfaceCard()
        .sheet(isPresented: $showingHistory) { ExerciseHistorySheet(name: exercise.name, unit: unit) }
        .alert("Exercise Note", isPresented: Binding(get: { noteDraft != nil }, set: { if !$0 { noteDraft = nil } })) {
            TextField("Note", text: Binding(get: { noteDraft ?? "" }, set: { noteDraft = $0 }))
            Button("Save") { ExerciseNote.set(noteDraft ?? "", for: exercise.name, in: context) }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var actions: some View {
        HStack(spacing: 16) {
            if exercise.info != nil {
                Button {
                    withAnimation(.snappy) { showingCue.toggle() }
                } label: {
                    ActionIcon(systemName: showingCue ? "info.circle.fill" : "info.circle")
                }
                .accessibilityLabel("Technique cue")
            }
            Button { showingHistory = true } label: { ActionIcon(systemName: "clock.arrow.circlepath") }
                .accessibilityLabel("History")
            Menu {
                if let onSwap {
                    Button("Swap Exercise", systemImage: "arrow.triangle.2.circlepath", action: onSwap)
                        .disabled(exercise.sets.contains(where: \.isDone))
                }
                Button("Add Set", systemImage: "plus", action: addSet)
                Button(notes.isEmpty ? "Add Note" : "Edit Note", systemImage: "note.text") {
                    noteDraft = notes.first?.text ?? ""
                }
                if !notes.isEmpty {
                    Button("Delete Note", systemImage: "trash", role: .destructive) {
                        ExerciseNote.set("", for: exercise.name, in: context)
                    }
                }
                Button("Remove Exercise", systemImage: "trash", role: .destructive, action: onRemove)
            } label: {
                ActionIcon.verticalEllipsis
            }
            .accessibilityLabel("Exercise menu")
        }
    }

    private var columnHeaders: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: SetColumns.menu, height: 1)
            Text("Weight").frame(width: SetColumns.field).padding(.leading, 12)
            Text("Reps").frame(width: SetColumns.field).padding(.leading, 16)
            Spacer(minLength: 0)
            Text("Log")
        }
        .font(Theme.columnHeader)
        .textCase(.uppercase)
        .foregroundStyle(Theme.text)
        .padding(.horizontal, Theme.gutter)
        .padding(.bottom, 4)
    }

    private func targetText(_ set: SetEntry, _ phase: WeekPhase) -> String {
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

    private func delete(_ set: SetEntry) {
        exercise.sets.removeAll { $0 === set }
        context.delete(set)
    }
}

struct SetRow: View {
    @Bindable var set: SetEntry
    let number: Int
    let unit: WeightUnit
    let rir: Int?
    var onCompleted: () -> Void
    var onAdd: () -> Void
    var onDelete: () -> Void

    private enum Field { case weight, reps }
    @FocusState private var focus: Field?

    private var weight: Binding<Double?> {
        Binding(get: { set.weight == 0 ? nil : set.weight }, set: { set.weight = $0 ?? 0 })
    }

    private var reps: Binding<Int?> {
        Binding(get: { set.reps == 0 ? nil : set.reps }, set: { set.reps = $0 ?? 0 })
    }

    var body: some View {
        HStack(spacing: 0) {
            Menu {
                Button("Add Set", systemImage: "plus", action: onAdd)
                Button("Delete Set", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                ActionIcon.verticalEllipsis.frame(width: SetColumns.menu, height: 44)
            }
            .accessibilityLabel("Set \(number) menu")

            TextField("Set \(number) weight", value: weight, format: .number,
                      prompt: Text(unit.rawValue).foregroundStyle(Theme.secondary))
                .keyboardType(.decimalPad)
                .focused($focus, equals: .weight)
                .themedField()
                .contentShape(Rectangle())
                .onTapGesture { focus = .weight }
                .accessibilityLabel("Set \(number) weight")
                .frame(width: SetColumns.field)
                .padding(.leading, 12)

            TextField("Set \(number) reps", value: reps, format: .number,
                      prompt: Text(rir.map { "\($0) RIR" } ?? "reps").foregroundStyle(Theme.secondary))
                .keyboardType(.numberPad)
                .focused($focus, equals: .reps)
                .themedField()
                .contentShape(Rectangle())
                .onTapGesture { focus = .reps }
                .accessibilityLabel("Set \(number) reps")
                .frame(width: SetColumns.field)
                .padding(.leading, 16)

            Spacer(minLength: 0)

            Button {
                set.isDone.toggle()
                if set.isDone { onCompleted() }
            } label: {
                LogCheckbox(isOn: set.isDone)
                    .frame(width: 44, height: 44, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log set \(number)")
            .accessibilityAddTraits(set.isDone ? .isSelected : [])
        }
        .padding(.horizontal, Theme.gutter)
        .frame(minHeight: 52)
    }
}

struct ExerciseHistorySheet: View {
    let name: String
    let unit: WeightUnit

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let last = lastFinishedExercise(named: name, in: context)
        let sets = last?.sortedSets.filter(\.isDone) ?? []
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let workout = last?.workout, !sets.isEmpty {
                        Text("\(workout.name) • \(workout.startDate.formatted(.dateTime.weekday(.wide).month().day()))")
                            .font(Theme.detail)
                            .foregroundStyle(Theme.secondary)
                            .padding(.horizontal, Theme.gutter)
                            .padding(.bottom, 8)
                        ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                            if index > 0 { Rectangle().fill(Theme.hairline).frame(height: 1) }
                            HStack {
                                Text("Set \(index + 1)").foregroundStyle(Theme.secondary)
                                Spacer()
                                Text("\(formatWeight(set.weight)) \(unit.rawValue) × \(set.reps)")
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.text)
                            }
                            .font(Theme.body)
                            .padding(.horizontal, Theme.gutter)
                            .frame(minHeight: 44)
                        }
                    } else {
                        Text("No finished session has this exercise yet.")
                            .font(Theme.body)
                            .foregroundStyle(Theme.secondary)
                            .padding(Theme.gutter)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
            }
            .background(Theme.surface)
            .navigationTitle(name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct SorenessCard: View {
    let muscle: Muscle
    let record: MuscleFeedbackRecord
    var onAnswer: (Soreness) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MuscleTag(muscle: muscle)
            VStack(alignment: .leading, spacing: 2) {
                Text("How did your \(muscle.displayName.lowercased()) recover?")
                    .font(Theme.cardTitle)
                    .foregroundStyle(Theme.text)
                if let previous = record.workout {
                    Text("Since \(previous.name), \(previous.startDate.formatted(.dateTime.weekday(.wide)))")
                        .font(Theme.detail)
                        .foregroundStyle(Theme.secondary)
                }
            }
            ChipPicker(title: "Soreness after that session", options: Soreness.allCases, columns: 2,
                       label: \.label, selection: nil) { if let soreness = $0 { onAnswer(soreness) } }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.bottom, 8)
        .surfaceCard()
    }
}

struct FeedbackCard: View {
    let muscle: Muscle
    let feedback: MuscleFeedback
    var onChange: ((inout MuscleFeedback) -> Void) -> Void

    private var isComplete: Bool { feedback.pump != nil && feedback.workload != nil && feedback.jointPain != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    MuscleTag(muscle: muscle)
                    Text("How did \(muscle.displayName.lowercased()) feel today?")
                        .font(Theme.cardTitle)
                        .foregroundStyle(Theme.text)
                }
                Spacer()
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.success)
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
                .font(Theme.caption)
                .foregroundStyle(Theme.secondary)
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.bottom, 8)
        .surfaceCard()
    }
}

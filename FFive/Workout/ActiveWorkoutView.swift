import FFiveCore
import SwiftData
import SwiftUI

/// The open workout on the Workout tab: a pinned header over a stream of exercise cards with their feedback,
/// and a pinned Finish button once every set is logged.
struct ActiveWorkoutView: View {
    @Bindable var workout: Workout
    /// The block in progress, also when the session shown is a quick workout.
    let activeMeso: Mesocycle?
    let openQuickWorkout: Workout?

    @Environment(Store.self) private var store
    @Environment(AppRouter.self) private var router

    @State private var picker: PickerRequest?
    @State private var showingSchedule = false
    @State private var confirmDiscard = false
    @State private var confirmEnd = false
    @State private var renameDraft: String?
    @State private var noteEdit: NoteEdit?
    @State private var historyFor: Exercise?
    @State private var setsCompleted = 0

    private struct NoteEdit: Identifiable {
        enum Target {
            case day
            case exercise(Exercise)

            var title: String {
                if case .exercise = self { "Exercise Note" } else { "Workout Note" }
            }
        }

        let target: Target
        let draft: String

        var id: String {
            switch target {
            case .day: "day"
            case .exercise(let exercise): "exercise:\(exercise.persistentModelID.hashValue)"
            }
        }
    }

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
        let pendingSoreness = store.pendingSoreness(in: workout)
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
                        exercises.firstIndex(where: { $0.muscle == muscle }) == index
                    {
                        SorenessCard(muscle: muscle, record: record) { soreness in
                            withAnimation {
                                store.recordSoreness(soreness, on: record, during: workout)
                            }
                        }
                    }

                    ExerciseCard(
                        exercise: exercise,
                        position: index + 1,
                        phase: workout.phase,
                        onSetCompleted: setCompleted,
                        onSwap: workout.mesocycle == nil ? nil : { picker = .swap(exercise) },
                        onShowHistory: { historyFor = exercise },
                        onEditNote: { noteEdit = NoteEdit(target: .exercise(exercise), draft: $0) }
                    ) {
                        store.removeExercise(exercise, from: workout)
                    }

                    if let muscle, workout.mesocycle != nil,
                        exercises.lastIndex(where: { $0.muscle == muscle }) == index,
                        exercise.isLogged
                    {
                        FeedbackCard(
                            muscle: muscle, feedback: workout.feedbackRecord(for: muscle)?.value ?? MuscleFeedback()
                        ) { change in
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
                    .buttonStyle(.floating)
                    .a11y(.workoutFinish)
                    .padding(.horizontal, Theme.gutter)
                    .padding(.vertical, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: exercises.map(\.isLogged))
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .a11y(.keyboardDone)
            }
        }
        .sensoryFeedback(.success, trigger: setsCompleted)
        .sheet(item: $picker) { request in
            switch request {
            case .add:
                ExercisePickerView { name, muscle in addExercise(name, muscle: muscle) }
            case .swap(let exercise):
                ExercisePickerView(title: "Swap \(exercise.name)", muscle: exercise.muscle) { name, muscle in
                    store.swapExercise(exercise, to: name, muscle: muscle)
                }
            }
        }
        .sheet(isPresented: $showingSchedule) {
            if let activeMeso {
                ScheduleSheet(
                    meso: activeMeso, week: workout.week ?? activeMeso.nextUp?.week ?? activeMeso.accumulationWeeks)
            }
        }
        .confirmationDialog("Discard this workout?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard Workout", role: .destructive, action: discard)
                .a11y(.dialogDiscard)
        } message: {
            Text(
                workout.mesocycle == nil
                    ? "Its exercises and sets are deleted."
                    : "Logged sets for this day are cleared and it starts over from the plan.")
        }
        .confirmationDialog("End this mesocycle?", isPresented: $confirmEnd, titleVisibility: .visible) {
            if let activeMeso {
                Button("End Mesocycle", role: .destructive) {
                    WorkoutTabActions.end(activeMeso, router: router, store: store)
                }
                .a11y(.dialogEndMesocycle)
            }
        } message: {
            Text("Logged sessions stay in Progress. You can plan a new block right after.")
        }
        .alert(
            "Rename Workout", isPresented: Binding(get: { renameDraft != nil }, set: { if !$0 { renameDraft = nil } })
        ) {
            TextField("Workout name", text: Binding(get: { renameDraft ?? "" }, set: { renameDraft = $0 }))
            Button("Save") {
                if let name = renameDraft?.trimmingCharacters(in: .whitespaces), !name.isEmpty { workout.name = name }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $noteEdit) { edit in
            NoteEditor(title: edit.target.title, draft: edit.draft) {
                saveNote($0, to: edit.target)
            }
        }
        .sheet(item: $historyFor) { ExerciseHistorySheet(name: $0.name) }
    }

    private func saveNote(_ text: String, to target: NoteEdit.Target) {
        switch target {
        case .day: store.setNote(text, on: workout)
        case .exercise(let exercise): store.setNote(text, on: exercise)
        }
    }

    private var header: some View {
        WorkoutHeader(title: headerTitle, subtitle: headerSubtitle, progress: workout.setProgress) {
            if activeMeso != nil {
                Button {
                    showingSchedule = true
                } label: {
                    ActionIcon.calendar
                }
                .accessibilityLabel("Schedule")
                .a11y(.workoutSchedule)
            }
            Menu {
                menuItems
            } label: {
                ActionIcon.verticalEllipsis
            }
            .accessibilityLabel("Workout menu")
            .a11y(.workoutMenu)
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
            .a11y(.menuAddExercise)
        if let meso = workout.mesocycle, let key = workout.key, meso.canSkip(key) {
            Button("Skip Day", systemImage: "forward") { skip(key, of: meso) }
                .a11y(.menuSkipDay)
        }
        if activeMeso != nil, openQuickWorkout !== workout {
            Button(
                openQuickWorkout == nil ? "Quick Workout" : "Resume Quick Workout",
                systemImage: openQuickWorkout == nil ? "bolt" : "play"
            ) {
                WorkoutTabActions.showQuickWorkout(openQuickWorkout, router: router, store: store)
            }
            .a11y(.menuQuickWorkout)
        }
        Button(workout.note == nil ? "Add Note" : "Edit Note", systemImage: "note.text") {
            noteEdit = NoteEdit(target: .day, draft: workout.note ?? "")
        }
        .a11y(.menuWorkoutNote)
        if workout.mesocycle == nil {
            Button("Rename", systemImage: "pencil") { renameDraft = workout.name }
                .a11y(.menuRename)
        }
        Button("Discard Workout", systemImage: "trash", role: .destructive) { confirmDiscard = true }
            .a11y(.menuDiscard)
        if activeMeso != nil {
            Button("End Mesocycle", systemImage: "flag.checkered", role: .destructive) { confirmEnd = true }
                .a11y(.menuEndMesocycle)
        }
    }

    private func setCompleted() {
        setsCompleted += 1
    }

    private func finish() {
        store.finish(workout)
        router.focus = nil
    }

    private func discard() {
        store.delete(workout)
    }

    private func skip(_ key: SessionKey, of meso: Mesocycle) {
        withAnimation { store.skip(key, of: meso) }
        router.focus = nil
    }

    private func addExercise(_ name: String, muscle: Muscle) {
        store.addExercise(named: name, muscle: muscle, to: workout)
    }
}

private enum SetColumns {
    static let menu: CGFloat = 32
    static let field: CGFloat = 93
}

struct ExerciseCard: View {
    let exercise: Exercise
    let position: Int
    let phase: WeekPhase?
    var onSetCompleted: () -> Void
    var onSwap: (() -> Void)?
    var onShowHistory: () -> Void
    var onEditNote: (String) -> Void
    var onRemove: () -> Void

    @Environment(Store.self) private var store
    @State private var showingCue = false

    var body: some View {
        let unit = store.settings.weightUnit
        let sets = exercise.sortedSets
        let pinned = store.pinnedNote(on: exercise)
        let note = pinned ?? exercise.note
        VStack(alignment: .leading, spacing: 0) {
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
                actions(note: note)
            }
            .padding(.horizontal, Theme.gutter)

            VStack(spacing: 8) {
                if let note {
                    HStack(spacing: 8) {
                        Callout(text: note, systemImage: "note.text", style: pinned == nil ? .note : .pinned)
                            .accessibilityLabel("Note: \(note)")
                        Button {
                            if pinned == nil { store.pinNote(on: exercise) } else { store.unpinNote(on: exercise) }
                        } label: {
                            ActionIcon(systemName: pinned == nil ? "pin" : "pin.fill")
                        }
                        .accessibilityLabel(pinned == nil ? "Pin note" : "Unpin note")
                        .a11y(.exercisePin, position)
                    }
                }
                if showingCue, let info = exercise.info {
                    Callout(
                        text: "\(info.cue) \(info.repRange.lowerBound)–\(info.repRange.upperBound) reps.",
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
                    SetRow(
                        set: set, number: index + 1, unit: unit, rir: phase?.rir,
                        onCompleted: onSetCompleted, onAdd: { store.addSet(to: exercise) }
                    ) { store.deleteSet(set, from: exercise) }
                }
            }
        }
        .surfaceCard(tag: exercise.muscle)
    }

    private func actions(note: String?) -> some View {
        HStack(spacing: 16) {
            if exercise.info != nil {
                Button {
                    withAnimation(.snappy) { showingCue.toggle() }
                } label: {
                    ActionIcon(systemName: showingCue ? "info.circle.fill" : "info.circle")
                }
                .accessibilityLabel("Technique cue")
                .a11y(.exerciseCue, position)
            }
            Button(action: onShowHistory) { ActionIcon(systemName: "clock.arrow.circlepath") }
                .accessibilityLabel("History")
                .a11y(.exerciseHistory, position)
            Menu {
                if let onSwap {
                    Button("Swap Exercise", systemImage: "arrow.triangle.2.circlepath", action: onSwap)
                        .disabled(exercise.sets.contains(where: \.isDone))
                        .a11y(.menuSwap)
                }
                Button("Add Set", systemImage: "plus") { store.addSet(to: exercise) }
                    .a11y(.menuAddSet)
                Button(note == nil ? "Add Note" : "Edit Note", systemImage: "note.text") {
                    onEditNote(note ?? "")
                }
                .a11y(.menuExerciseNote)
                if note != nil {
                    Button("Delete Note", systemImage: "trash", role: .destructive) {
                        store.deleteNote(on: exercise)
                    }
                    .a11y(.menuDeleteNote)
                }
                Button("Remove Exercise", systemImage: "trash", role: .destructive, action: onRemove)
                    .a11y(.menuRemoveExercise)
            } label: {
                ActionIcon.verticalEllipsis
            }
            .accessibilityLabel("Exercise menu")
            .a11y(.exerciseMenu, position)
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
        guard let reps = set.targetReps else {
            return "Target \(formatWeight(weight)) \(store.settings.weightUnit.rawValue)"
        }
        return weight == 0 ? "Target \(reps) reps" : "Target \(formatWeight(weight)) × \(reps)"
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

    @Environment(Store.self) private var store

    private enum Field { case weight, reps }
    @FocusState private var focus: Field?

    /// Zero reads as "not entered yet", so the field shows its placeholder instead of a 0.
    private var weight: Binding<Double?> {
        Binding(get: { set.weight == 0 ? nil : set.weight }, set: { set.weight = $0 ?? 0 })
    }

    private var reps: Binding<Int?> {
        Binding(get: { set.reps == 0 ? nil : set.reps }, set: { set.reps = $0 ?? 0 })
    }

    private var setType: Binding<SetType> {
        Binding(get: { set.type }, set: { store.setType($0, of: set) })
    }

    var body: some View {
        HStack(spacing: 0) {
            Menu {
                Button("Add Set", systemImage: "plus", action: onAdd)
                    .a11y(.menuAddSet)
                Picker("Set Type", selection: setType) {
                    ForEach(SetType.allCases) { Text($0.title).tag($0) }
                }
                .a11y(.menuSetType)
                Button("Delete Set", systemImage: "trash", role: .destructive, action: onDelete)
                    .a11y(.menuDeleteSet)
            } label: {
                ActionIcon.verticalEllipsis.frame(width: SetColumns.menu, height: 44)
            }
            .accessibilityLabel(set.type.tag == nil ? "Set \(number) menu" : "Set \(number) menu, \(set.type.title)")
            .a11y(.setMenu, number)

            TextField(
                "Set \(number) weight", value: weight, format: .number,
                prompt: Text(unit.rawValue).foregroundStyle(Theme.secondary)
            )
            .keyboardType(.decimalPad)
            .focused($focus, equals: .weight)
            .themedField()
            .contentShape(Rectangle())
            .onTapGesture { focus = .weight }
            .accessibilityLabel("Set \(number) weight")
            .a11y(.setWeight, number)
            .frame(width: SetColumns.field)
            .padding(.leading, 12)

            TextField(
                "Set \(number) reps", value: reps, format: .number,
                prompt: Text(rir.map { "\($0) RIR" } ?? "reps").foregroundStyle(Theme.secondary)
            )
            .keyboardType(.numberPad)
            .focused($focus, equals: .reps)
            .themedField()
            .contentShape(Rectangle())
            .onTapGesture { focus = .reps }
            .accessibilityLabel("Set \(number) reps")
            .a11y(.setReps, number)
            .frame(width: SetColumns.field)
            .padding(.leading, 16)

            if let tag = set.type.tag {
                Text(tag)
                    .font(Theme.caption.weight(.medium))
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.leading, 8)
                    .accessibilityHidden(true)
            }

            Spacer(minLength: 0)

            Button {
                store.log(set, done: !set.isDone)
                if set.isDone { onCompleted() }
            } label: {
                LogCheckbox(isOn: set.isDone)
                    .frame(width: 44, height: 44, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log set \(number)")
            .a11y(.setLog, number)
            .accessibilityAddTraits(set.isDone ? .isSelected : [])
        }
        .padding(.horizontal, Theme.gutter)
        .frame(minHeight: 52)
    }
}

/// The sets logged for an exercise the last time it was trained.
struct ExerciseHistorySheet: View {
    let name: String

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let unit = store.settings.weightUnit
        let last = store.lastFinishedExercise(ExerciseID(folding: name))
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
                                if let tag = set.type.tag {
                                    Text(tag).font(Theme.caption.weight(.medium)).foregroundStyle(Theme.secondary)
                                }
                                Spacer()
                                Text("\(formatWeight(set.weight)) \(unit.rawValue) × \(set.reps)")
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.text)
                            }
                            .font(Theme.body)
                            .padding(.horizontal, Theme.gutter)
                            .frame(minHeight: 44)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(
                                "Set \(index + 1)\(set.type.tag == nil ? "" : ", \(set.type.title)"), \(formatWeight(set.weight)) \(unit.rawValue) × \(set.reps)"
                            )
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
                        .a11y(.sheetDone)
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
            ChipPicker(
                title: "Soreness after that session", options: Soreness.allCases, columns: 2,
                label: \.label, selection: nil
            ) { if let soreness = $0 { onAnswer(soreness) } }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.bottom, 8)
        .surfaceCard(tag: muscle)
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
                Text("How did \(muscle.displayName.lowercased()) feel today?")
                    .font(Theme.cardTitle)
                    .foregroundStyle(Theme.text)
                Spacer()
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.success)
                }
            }
            ChipPicker(title: "Pump", options: Pump.allCases, columns: 3, label: \.label, selection: feedback.pump) {
                value in
                onChange { $0.pump = value }
            }
            ChipPicker(
                title: "Workload", options: Workload.allCases, columns: 2, label: \.label, selection: feedback.workload
            ) { value in
                onChange { $0.workload = value }
            }
            ChipPicker(
                title: "Joint pain", options: JointPain.allCases, columns: 4, label: \.label,
                selection: feedback.jointPain
            ) { value in
                onChange { $0.jointPain = value }
            }
            Text(
                "Next week's sets for \(muscle.displayName.lowercased()) come from these answers and how sore you get."
            )
            .font(Theme.caption)
            .foregroundStyle(Theme.secondary)
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.bottom, 8)
        .surfaceCard(tag: muscle)
    }
}

/// Notes edit in a sheet, not an alert, because an alert's text field kept the old text after it was cleared and retyped.
private struct NoteEditor: View {
    let title: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: String
    @FocusState private var focused: Bool

    init(title: String, draft: String, onSave: @escaping (String) -> Void) {
        self.title = title
        self.onSave = onSave
        _draft = State(initialValue: draft)
    }

    var body: some View {
        NavigationStack {
            VStack {
                TextField("Note", text: $draft, axis: .vertical)
                    .font(Theme.body)
                    .foregroundStyle(Theme.text)
                    .lineLimit(3...8)
                    .focused($focused)
                    .accessibilityLabel("Note")
                    .a11y(.noteText)
                    .padding(12)
                    .background(Theme.field, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                Spacer()
            }
            .padding(Theme.gutter)
            .background(Theme.page)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .a11y(.noteCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .a11y(.noteSave)
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear { focused = true }
    }
}

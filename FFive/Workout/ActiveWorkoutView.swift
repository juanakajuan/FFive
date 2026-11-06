import FFiveCore
import SwiftData
import SwiftUI

struct ActiveWorkoutView: View {
    @Bindable var workout: Workout
    let activeMeso: Mesocycle?
    let openQuickWorkout: Workout?

    @Environment(Store.self) private var store
    @Environment(AppRouter.self) private var router

    @State private var picker: PickerRequest?
    @State private var showingSchedule = false
    @State private var showingReorder = false
    @State private var confirmDiscard = false
    @State private var confirmReset = false
    @State private var confirmEnd = false
    @State private var renameDraft: String?
    @State private var bodyweightDraft: String?
    @State private var article: Learn.Article?
    @State private var noteEdit: NoteEdit?
    @State private var historyFor: Exercise?
    @State private var feedbackFor: Muscle?
    @State private var feedbackRequired: FeedbackBlock?
    @State private var sorenessAsk: SorenessAsk?
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

    /// A refused set log: the exercise tapped, and the muscle whose feedback it waits for.
    private struct FeedbackBlock: Equatable {
        let muscle: Muscle
        let exercise: PersistentIdentifier
    }

    /// The muscle's first log tap, held until soreness since its last session is answered.
    private struct SorenessAsk: Identifiable {
        let muscle: Muscle
        let record: MuscleFeedbackRecord
        let set: SetEntry

        var id: Muscle { muscle }
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
        sessionList(workout.sortedExercises)
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
            .sheet(isPresented: $showingReorder) { ReorderExercisesView(workout: workout) }
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
                        : "This day is rebuilt from the plan. Logged sets, swaps and added exercises are dropped.")
            }
            .confirmationDialog("Reset this workout?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset Workout", role: .destructive) { store.reset(workout) }
                    .a11y(.dialogReset)
            } message: {
                Text("Logged sets are cleared. Exercises and targets stay.")
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
                workout.mesocycle == nil ? "Rename Workout" : "Rename Day",
                isPresented: Binding(get: { renameDraft != nil }, set: { if !$0 { renameDraft = nil } })
            ) {
                TextField(
                    workout.mesocycle == nil ? "Workout name" : "Day name",
                    text: Binding(get: { renameDraft ?? "" }, set: { renameDraft = $0 }))
                Button("Save") {
                    if let name = renameDraft { store.rename(workout, to: name) }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert(
                "Bodyweight",
                isPresented: Binding(get: { bodyweightDraft != nil }, set: { if !$0 { bodyweightDraft = nil } })
            ) {
                TextField(
                    "Bodyweight (\(store.settings.weightUnit.rawValue))",
                    text: Binding(get: { bodyweightDraft ?? "" }, set: { bodyweightDraft = $0 })
                )
                .keyboardType(.decimalPad)
                Button("Save") {
                    let text = (bodyweightDraft ?? "").trimmingCharacters(in: .whitespaces)
                    store.setBodyweight(Double(text.replacing(",", with: ".")), of: workout)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Bodyweight lifts log the load you add to it. Leave it empty to clear.")
            }
            .sheet(item: $noteEdit) { edit in
                NoteEditor(title: edit.target.title, draft: edit.draft) {
                    saveNote($0, to: edit.target)
                }
            }
            .sheet(item: $historyFor) { ExerciseHistorySheet(name: $0.name) }
            .sheet(item: $article) { Learn.ArticleSheet(article: $0) }
            .sheet(item: $sorenessAsk) { ask in
                SorenessSheet(muscle: ask.muscle, record: ask.record) { soreness in
                    store.recordSoreness(soreness, on: ask.record, during: workout, logging: ask.set)
                    setCompleted()
                }
            }
            .sheet(item: $feedbackFor) { muscle in
                FeedbackSheet(muscle: muscle, feedback: workout.feedbackRecord(for: muscle)?.value ?? MuscleFeedback())
                {
                    answers in
                    store.updateFeedback(for: muscle, in: workout) {
                        $0.pump = answers.pump
                        $0.workload = answers.workload
                        $0.jointPain = answers.jointPain
                    }
                }
            }
    }

    /// What a log tap on this exercise does instead of logging: point at the feedback it waits for, or ask the
    /// muscle's soreness first. Nil logs the set.
    private func logGate(for exercise: Exercise, unrated: Muscle?, soreness: MuscleFeedbackRecord?)
        -> ((SetEntry) -> Void)?
    {
        if let unrated {
            return { _ in feedbackRequired = FeedbackBlock(muscle: unrated, exercise: exercise.persistentModelID) }
        }
        guard let muscle = exercise.muscle, let soreness else { return nil }
        return { set in sorenessAsk = SorenessAsk(muscle: muscle, record: soreness, set: set) }
    }

    /// A muscle that finished before this exercise's muscle and still has no feedback. Its sets wait for that answer.
    private func unratedMuscle(before exercise: Exercise, in exercises: [Exercise]) -> Muscle? {
        feedbackMuscles(in: exercises).first {
            $0 != exercise.muscle && workout.feedbackRecord(for: $0)?.value.isRated != true
        }
    }

    /// Muscles whose last exercise has no pending set, so their feedback is due. Only block sessions collect it.
    private func feedbackMuscles(in exercises: [Exercise]) -> [Muscle] {
        guard workout.mesocycle != nil else { return [] }
        var seen = Set<Muscle>()
        return exercises.compactMap(\.muscle).filter { seen.insert($0).inserted }.filter { muscle in
            exercises.last { $0.muscle == muscle }?.isLogged == true
        }
    }

    /// The session's cards, with the feedback toast and the sheet that opens when a muscle finishes.
    private func sessionList(_ exercises: [Exercise]) -> some View {
        let pendingSoreness = store.pendingSoreness(in: workout)
        return ScrollView {
            LazyVStack(spacing: 16) {
                if let note = workout.note {
                    Callout(text: note, systemImage: "note.text", style: .note)
                        .padding(.horizontal, Theme.gutter)
                        .accessibilityLabel("Workout note: \(note)")
                }
                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                    exerciseRow(exercise, at: index, in: exercises, pendingSoreness: pendingSoreness)
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
        .animation(.snappy, value: feedbackRequired)
        .task(id: feedbackRequired) {
            guard let block = feedbackRequired else { return }
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            feedbackRequired = nil
            feedbackFor = block.muscle
        }
        .onChange(of: feedbackMuscles(in: exercises)) { old, new in
            feedbackFor = new.first { !old.contains($0) && workout.feedbackRecord(for: $0)?.value.isRated != true }
        }
    }

    /// The muscle's joint pain for this session, shared by its exercise menus and its feedback card.
    /// Only block sessions collect feedback, so quick workouts get none.
    private func jointPain(for muscle: Muscle?) -> Binding<JointPain?>? {
        guard let muscle, workout.mesocycle != nil else { return nil }
        return Binding(
            get: { workout.feedbackRecord(for: muscle)?.value.jointPain },
            set: { value in store.updateFeedback(for: muscle, in: workout) { $0.jointPain = value } })
    }

    @ViewBuilder
    private func exerciseRow(
        _ exercise: Exercise, at index: Int, in exercises: [Exercise],
        pendingSoreness: [Muscle: MuscleFeedbackRecord]
    ) -> some View {
        let muscle = exercise.muscle
        let unrated = unratedMuscle(before: exercise, in: exercises)
        ExerciseCard(
            exercise: exercise,
            position: index + 1,
            phase: workout.phase,
            onSetCompleted: setCompleted,
            isLocked: unrated != nil,
            onLogBlocked: logGate(for: exercise, unrated: unrated, soreness: muscle.flatMap { pendingSoreness[$0] }),
            feedbackRequiredFor: feedbackRequired.flatMap {
                $0.exercise == exercise.persistentModelID ? $0.muscle : nil
            },
            onSwap: workout.mesocycle == nil ? nil : { picker = .swap(exercise) },
            jointPain: jointPain(for: muscle),
            onShowHistory: { historyFor = exercise },
            onEditNote: { noteEdit = NoteEdit(target: .exercise(exercise), draft: $0) },
            onRemove: { store.removeExercise(exercise, from: workout) },
            onOpenArticle: { article = $0 }
        )

        if let muscle, workout.mesocycle != nil,
            exercises.lastIndex(where: { $0.muscle == muscle }) == index,
            exercise.isLogged
        {
            FeedbackCard(
                muscle: muscle, feedback: workout.feedbackRecord(for: muscle)?.value ?? MuscleFeedback()
            ) { feedbackFor = muscle }
        }
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
        if workout.exercises.count > 1 {
            Button("Reorder Exercises", systemImage: "arrow.up.arrow.down") { showingReorder = true }
                .a11y(.menuReorder)
        }
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
        Button(
            workout.bodyweight.map { "Bodyweight · \(formatWeight($0)) \(store.settings.weightUnit.rawValue)" }
                ?? "Set Bodyweight",
            systemImage: "figure.stand"
        ) {
            bodyweightDraft = workout.bodyweight.map(formatWeight) ?? ""
        }
        .a11y(.menuBodyweight)
        Button(workout.mesocycle == nil ? "Rename" : "Rename Day", systemImage: "pencil") { renameDraft = workout.name }
            .a11y(.menuRename)
        if workout.mesocycle != nil, workout.setProgress > 0 {
            Button("Reset Workout", systemImage: "arrow.counterclockwise", role: .destructive) { confirmReset = true }
                .a11y(.menuReset)
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
    static let log: CGFloat = 44
}

struct ExerciseCard: View {
    let exercise: Exercise
    let position: Int
    let phase: WeekPhase?
    var onSetCompleted: () -> Void
    /// Greyed out while another muscle's feedback is owed.
    var isLocked = false
    /// Called instead of logging an unlogged set, with that set.
    var onLogBlocked: ((SetEntry) -> Void)?
    /// The muscle whose feedback a refused log tap here waits for, shown over the card.
    var feedbackRequiredFor: Muscle?
    var onSwap: (() -> Void)?
    var jointPain: Binding<JointPain?>?
    var onShowHistory: () -> Void
    var onEditNote: (String) -> Void
    var onRemove: () -> Void
    var onOpenArticle: (Learn.Article) -> Void

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
                    Text(subtitle(unit: unit))
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
                        text: [info.cue, "\(info.repRange.lowerBound)–\(info.repRange.upperBound) reps."]
                            .compactMap { $0 }.joined(separator: " "),
                        systemImage: "lightbulb.fill")
                }
                if exercise.isBodyweight, exercise.workout?.bodyweight == nil {
                    Callout(
                        text: "Set your bodyweight in the workout menu to track strength on this lift.",
                        systemImage: "figure.stand")
                }
                if let phase, let set = sets.first(where: { $0.status == .pending }) ?? sets.first {
                    Callout(text: targetText(set, phase))
                }
                if let tip = CoachingTip.applicable(to: exercise, dismissed: store.settings.dismissedTips) {
                    CoachingTipCallout(tip: tip, position: position, onLearnMore: onOpenArticle) {
                        withAnimation(.snappy) { store.settings.dismiss(tip) }
                    }
                    .transition(.opacity)
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
                        onCompleted: onSetCompleted, onLogBlocked: onLogBlocked, onAdd: { store.addSet(to: exercise) }
                    ) { store.deleteSet(set, from: exercise) }
                }
            }
        }
        .surfaceCard(tag: exercise.muscle)
        .opacity(isLocked ? 0.4 : 1)
        .overlay {
            if let feedbackRequiredFor {
                FeedbackRequiredToast(muscle: feedbackRequiredFor).transition(
                    .scale(scale: 0.9).combined(with: .opacity))
            }
        }
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
                if exercise.sets.contains(where: { $0.status == .pending }) {
                    Button("Skip Remaining Sets", systemImage: "forward.end") {
                        store.skipRemainingSets(of: exercise)
                    }
                    .a11y(.menuSkipRemaining)
                }
                if let jointPain {
                    Picker(selection: jointPain) {
                        ForEach(JointPain.allCases, id: \.self) { Text($0.label).tag(Optional($0)) }
                    } label: {
                        Label("Joint Pain", systemImage: "bandage")
                        if let pain = jointPain.wrappedValue { Text(pain.label) }
                    }
                    .pickerStyle(.menu)
                    .a11y(.menuJointPain)
                }
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

    private func subtitle(unit: WeightUnit) -> String {
        guard exercise.isBodyweight else { return exercise.info?.equipment.displayName ?? "Custom" }
        return exercise.workout?.bodyweight.map { "Bodyweight · \(formatWeight($0)) \(unit.rawValue)" } ?? "Bodyweight"
    }

    private var columnHeaders: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: SetColumns.menu, height: 1)
            Text(exercise.isBodyweight ? "BW +/−" : "Weight").frame(minWidth: SetColumns.field, maxWidth: .infinity)
                .padding(.leading, 12)
            Text("Reps").frame(minWidth: SetColumns.field, maxWidth: .infinity).padding(.leading, 16)
            Text("Log").frame(width: SetColumns.log, alignment: .trailing).padding(.leading, 16)
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
            return "Target \(exercise.weightText(weight, unit: store.settings.weightUnit))"
        }
        return weight == 0 && !exercise.isBodyweight
            ? "Target \(reps) reps" : "Target \(exercise.weightText(weight)) × \(reps)"
    }
}

struct SetRow: View {
    @Bindable var set: SetEntry
    let number: Int
    let unit: WeightUnit
    let rir: Int?
    var onCompleted: () -> Void
    var onLogBlocked: ((SetEntry) -> Void)?
    var onAdd: () -> Void
    var onDelete: () -> Void

    @Environment(Store.self) private var store

    private enum Field { case weight, reps }
    @FocusState private var focus: Field?
    @State private var followers: [SetEntry] = []

    /// Zero reads as "not entered yet", so the field shows its placeholder instead of a 0.
    private var weight: Binding<Double?> {
        Binding(
            get: { set.weight == 0 ? nil : set.weight },
            set: { store.setWeight($0 ?? 0, of: set, carryingTo: followers) })
    }

    private var isBodyweight: Bool { self.set.exercise?.isBodyweight ?? false }

    private var reps: Binding<Int?> {
        Binding(get: { set.reps == 0 ? nil : set.reps }, set: { store.setReps($0 ?? 0, of: set) })
    }

    private var setType: Binding<SetType> {
        Binding(get: { set.type }, set: { store.setType($0, of: set) })
    }

    var body: some View {
        HStack(spacing: 0) {
            Menu {
                Button("Add Set", systemImage: "plus", action: onAdd)
                    .a11y(.menuAddSet)
                switch set.status {
                case .pending:
                    Button("Skip Set", systemImage: "forward.end") { store.skip(set, skipped: true) }
                        .a11y(.menuSkipSet)
                case .skipped:
                    Button("Unskip Set", systemImage: "arrow.uturn.backward") { store.skip(set, skipped: false) }
                        .a11y(.menuSkipSet)
                case .done:
                    EmptyView()
                }
                Picker("Set Type", selection: setType) {
                    ForEach(SetType.allCases) { Text($0.title).tag($0) }
                }
                .a11y(.menuSetType)
                Button("Delete Set", systemImage: "trash", role: .destructive, action: onDelete)
                    .a11y(.menuDeleteSet)
            } label: {
                VStack(spacing: 2) {
                    if let tag = set.type.tag {
                        ActionIcon.verticalEllipsis.scaleEffect(0.75).frame(height: 22)
                        Text(tag)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.infoText)
                            .lineLimit(1)
                            .fixedSize()
                    } else {
                        ActionIcon.verticalEllipsis
                    }
                }
                .frame(width: SetColumns.menu, height: 44)
            }
            .accessibilityLabel(set.type.tag == nil ? "Set \(number) menu" : "Set \(number) menu, \(set.type.title)")
            .a11y(.setMenu, number)

            TextField(
                "Set \(number) weight", value: weight, format: .number,
                prompt: Text(isBodyweight ? "BW" : unit.rawValue).foregroundStyle(Theme.secondary)
            )
            .keyboardType(isBodyweight ? .numbersAndPunctuation : .decimalPad)
            .focused($focus, equals: .weight)
            .onChange(of: focus) { _, new in
                followers = new == .weight ? store.weightFollowers(of: set) : []
            }
            .themedField()
            .contentShape(Rectangle())
            .onTapGesture { focus = .weight }
            .accessibilityLabel("Set \(number) weight")
            .a11y(.setWeight, number)
            .frame(minWidth: SetColumns.field, maxWidth: .infinity)
            .padding(.leading, 12)
            .opacity(set.status == .skipped ? 0.4 : 1)

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
            .frame(minWidth: SetColumns.field, maxWidth: .infinity)
            .padding(.leading, 16)
            .opacity(set.status == .skipped ? 0.4 : 1)

            Button {
                if !set.isDone, let onLogBlocked {
                    onLogBlocked(set)
                    return
                }
                store.log(set, done: !set.isDone)
                if set.isDone { onCompleted() }
            } label: {
                LogCheckbox(status: set.status)
                    .frame(width: SetColumns.log, height: 44, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!set.canToggleLog)
            .padding(.leading, 16)
            .accessibilityLabel("Log set \(number)")
            .a11y(.setLog, number)
            .accessibilityValue(set.status == .skipped ? "Skipped" : "")
            .accessibilityAddTraits(set.isDone ? .isSelected : [])
        }
        .padding(.horizontal, Theme.gutter)
        .frame(minHeight: 52)
    }
}

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
                                Text("\(set.weightText(unit: unit)) × \(set.reps)")
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.text)
                            }
                            .font(Theme.body)
                            .padding(.horizontal, Theme.gutter)
                            .frame(minHeight: 44)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(
                                "Set \(index + 1)\(set.type.tag == nil ? "" : ", \(set.type.title)"), \(set.weightText(unit: unit)) × \(set.reps)"
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

/// Asks how a muscle recovered since its last session, before its first set today is logged.
struct SorenessSheet: View {
    let muscle: Muscle
    let record: MuscleFeedbackRecord
    let onSave: (Soreness) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: Soreness?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
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
                        label: \.label, selection: draft
                    ) { draft = $0 }
                    Text("Today's sets for \(muscle.displayName.lowercased()) are planned from this answer.")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.secondary)
                }
                .padding(Theme.gutter)
            }
            .background(Theme.page)
            .navigationTitle("\(muscle.displayName) Recovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .a11y(.sorenessCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let draft { onSave(draft) }
                        dismiss()
                    }
                    .disabled(draft == nil)
                    .a11y(.sorenessSave)
                }
            }
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled(draft != nil)
    }
}

extension MuscleFeedback {
    fileprivate var isRated: Bool { pump != nil && workload != nil && jointPain != nil }
}

/// The muscle's end-of-session feedback in the list: a summary that opens `FeedbackSheet`.
struct FeedbackCard: View {
    let muscle: Muscle
    let feedback: MuscleFeedback
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("How did \(muscle.displayName.lowercased()) feel today?")
                        .font(Theme.cardTitle)
                        .foregroundStyle(Theme.text)
                        .multilineTextAlignment(.leading)
                    Text(summary)
                        .font(Theme.detail)
                        .foregroundStyle(Theme.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: feedback.isRated ? "checkmark.circle.fill" : "chevron.right")
                    .font(.system(size: feedback.isRated ? 22 : 15, weight: .semibold))
                    .foregroundStyle(feedback.isRated ? Theme.success : Theme.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .a11y(.feedbackOpen, key: muscle.rawValue)
        .padding(.horizontal, Theme.gutter)
        .padding(.bottom, 8)
        .surfaceCard(tag: muscle)
    }

    private var summary: String {
        guard feedback.isRated, let pump = feedback.pump, let workload = feedback.workload,
            let jointPain = feedback.jointPain
        else { return "Rate pump, workload and joint pain" }
        return "Pump \(pump.label.lowercased()) · \(workload.label) · Joint pain \(jointPain.label.lowercased())"
    }
}

private struct FeedbackRequiredToast: View {
    let muscle: Muscle

    var body: some View {
        Label("Rate \(muscle.displayName.lowercased()) first", systemImage: "info.circle")
            .font(Theme.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Theme.danger, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .shadow(radius: 8)
            .accessibilityAddTraits(.isStaticText)
            .a11y(.feedbackRequired)
    }
}

/// Asks pump, workload and joint pain on a draft; Save writes all three, Cancel drops them.
struct FeedbackSheet: View {
    let muscle: Muscle
    let original: MuscleFeedback
    let onSave: (MuscleFeedback) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: MuscleFeedback

    init(muscle: Muscle, feedback: MuscleFeedback, onSave: @escaping (MuscleFeedback) -> Void) {
        self.muscle = muscle
        self.original = feedback
        self.onSave = onSave
        _draft = State(initialValue: feedback)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("How did \(muscle.displayName.lowercased()) feel today?")
                        .font(Theme.cardTitle)
                        .foregroundStyle(Theme.text)
                    ChipPicker(title: "Pump", options: Pump.allCases, columns: 3, label: \.label, selection: draft.pump)
                    {
                        draft.pump = $0
                    }
                    ChipPicker(
                        title: "Workload", options: Workload.allCases, columns: 2, label: \.label,
                        selection: draft.workload
                    ) { draft.workload = $0 }
                    ChipPicker(
                        title: "Joint pain", options: JointPain.allCases, columns: 4, label: \.label,
                        selection: draft.jointPain
                    ) { draft.jointPain = $0 }
                    Text(
                        "Next week's sets for \(muscle.displayName.lowercased()) come from these answers and how sore you get."
                    )
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondary)
                }
                .padding(Theme.gutter)
            }
            .background(Theme.page)
            .navigationTitle("\(muscle.displayName) Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .a11y(.feedbackCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(!draft.isRated)
                    .a11y(.feedbackSave)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(draft != original)
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

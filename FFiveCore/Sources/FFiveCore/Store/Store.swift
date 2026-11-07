import Foundation
import Observation
import SwiftData

public enum StoreError: Error, Equatable {
    case anotherMesocycleIsActive
    case nameEmpty
    case nameTaken
}

@MainActor
@Observable
public final class Store {
    public let container: ModelContainer
    public let settings: Settings
    let context: ModelContext
    private var revision = 0
    /// The error of the last commit that did not save, until a screen has shown it.
    public private(set) var failure: (any Error)?

    public convenience init(inMemory: Bool, settings: Settings) {
        self.init(container: AppStore.makeContainer(inMemory: inMemory), settings: settings)
    }

    init(container: ModelContainer, settings: Settings) {
        self.container = container
        context = container.mainContext
        self.settings = settings
        backfillExerciseKeys()
        backfillCustomExercises()
    }

    public convenience init(inMemory: Bool) {
        self.init(inMemory: inMemory, settings: Settings())
    }

    private var unit: WeightUnit { settings.weightUnit }

    @ObservationIgnored private var cachedSnapshot: PlanningSnapshot?
    private var snapshot: PlanningSnapshot {
        if let cachedSnapshot { return cachedSnapshot }
        let built = PlanningSnapshot(context: context)
        cachedSnapshot = built
        return built
    }

    public func startMesocycle(_ draft: MesoDraft) throws {
        guard try context.fetchCount(Mesocycle.active) == 0 else { throw StoreError.anotherMesocycleIsActive }
        MesoPlanner.start(draft, in: context)
        commit()
    }

    public func endMesocycle(_ meso: Mesocycle) {
        meso.end(in: context)
        commit()
    }

    public func deleteMesocycle(_ meso: Mesocycle) {
        meso.delete(in: context)
        commit()
    }

    public func saveTemplate(from draft: MesoDraft, named name: String) {
        saveTemplate(CustomTemplate.layout(of: draft), named: name, fallback: draft.name)
    }

    public func saveTemplate(from meso: Mesocycle, named name: String) {
        saveTemplate(CustomTemplate.layout(of: meso), named: name, fallback: meso.name)
    }

    private func saveTemplate(_ days: [CustomTemplate.Layout.Day], named name: String, fallback: String) {
        guard !days.isEmpty else { return }
        context.insert(CustomTemplate(name: uniqueTemplateName(name.noteText ?? fallback), days: days))
        commit()
    }

    public func rename(_ template: CustomTemplate, to name: String) {
        guard let name = name.noteText, name != template.name else { return }
        template.name = uniqueTemplateName(name)
        commit()
    }

    public func delete(_ template: CustomTemplate) {
        context.delete(template)
        commit()
    }

    /// Every template name, built-in or custom, stays unique, so a name picks out one template.
    func uniqueTemplateName(_ wanted: String) -> String {
        let custom = (try? context.fetch(CustomTemplate.all)) ?? []
        let taken = Set((ExerciseCatalog.templates.map(\.name) + custom.map(\.name)).map { $0.lowercased() })
        guard taken.contains(wanted.lowercased()) else { return wanted }
        return (2...).lazy.map { "\(wanted) \($0)" }.first { !taken.contains($0.lowercased()) }!
    }

    public func skip(_ key: SessionKey, of meso: Mesocycle) {
        meso.skip(key, in: context)
        commit()
    }

    public func reset(_ workout: Workout) {
        workout.reset(in: context)
        commit()
    }

    public func rename(_ workout: Workout, to name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let meso = workout.mesocycle, let dayIndex = workout.dayIndex {
            meso.renameDay(dayIndex, to: name)
        }
        workout.name = name
        commit()
    }

    /// Nil clears the label. A session outside a block has no day to label, so it is left alone.
    public func relabel(_ workout: Workout, as weekday: Weekday?, scope: WeekdayScope) {
        guard let meso = workout.mesocycle, let dayIndex = workout.dayIndex else { return }
        switch scope {
        case .thisSession: workout.weekday = weekday
        case .everyWeek: meso.relabelDay(dayIndex, as: weekday)
        }
        commit()
    }

    public func rename(_ meso: Mesocycle, to name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        meso.name = name
        commit()
    }

    /// Blank text adds nothing; text past `MesoNote.maxLength` is cut to it.
    public func addNote(_ text: String, to meso: Mesocycle) {
        meso.addNote(text)
        commit()
    }

    public func deleteNote(_ note: MesoNote, from meso: Mesocycle) {
        meso.deleteNote(note)
        commit()
    }

    public func setPriority(_ priority: MusclePriority, of muscle: Muscle, in meso: Mesocycle) {
        meso.setPriority(priority, of: muscle)
        commit()
    }

    public func unskip(_ key: SessionKey, of meso: Mesocycle) {
        meso.unskip(key)
        commit()
    }

    /// Adds an accumulation week before the deload, or removes the last one, and rebuilds the unlogged sessions
    /// already built for the weeks that changed. A change `Mesocycle.canAddWeek` or `canRemoveWeek` refuses does nothing.
    public func changeLength(of meso: Mesocycle, by delta: Int) {
        guard let rebuild = meso.changeLength(by: delta, in: context) else { return }
        for workout in rebuild { MesoPlanner.rebuild(workout, unit: unit, snapshot: snapshot, in: context) }
        commit()
    }

    @discardableResult
    public func buildSession(_ meso: Mesocycle, at key: SessionKey) -> Workout {
        let workout = MesoPlanner.workout(for: meso, at: key, unit: unit, snapshot: snapshot, in: context)
        commit()
        return workout
    }

    public func weeklyVolume(_ meso: Mesocycle, week: Int) -> [MuscleVolume] {
        MesoPlanner.weeklyVolume(meso, week: week, unit: unit, snapshot: snapshot)
    }

    /// A block day is built as soon as the tab shows it. Until a set is logged its clock restarts each time it is
    /// shown, so duration and the soreness lookback count from when training began.
    public func show(_ workout: Workout) {
        guard workout.mesocycle != nil, workout.completedSets == 0 else { return }
        workout.startDate = .now
        commit()
    }

    /// Logging the first set of a block day restarts its clock one last time, so duration counts from the first lift.
    /// A call that breaks the order or logs an empty set changes nothing.
    public func log(_ set: SetEntry, done: Bool) {
        guard done != set.isDone, set.canToggleLog else { return }
        if done, let workout = set.exercise?.workout, workout.mesocycle != nil, workout.completedSets == 0 {
            workout.startDate = .now
        }
        set.status = done ? .done : .pending
        commit()
    }

    public func skip(_ set: SetEntry, skipped: Bool) {
        set.status = skipped ? .skipped : .pending
        commit()
    }

    public func skipRemainingSets(of exercise: Exercise) {
        exercise.skipRemainingSets()
        commit()
    }

    public func setType(_ type: SetType, of set: SetEntry) {
        set.type = type
        commit()
    }

    /// The later unlogged sets that share `set`'s weight right now. Capture this once when editing starts: clearing
    /// the field writes 0 on the way to the new number, and a recount then would sweep in unrelated empty sets.
    public func weightFollowers(of set: SetEntry) -> [SetEntry] {
        guard settings.autoMatchWeights, let exercise = set.exercise else { return [] }
        return exercise.laterSets(matchingWeightOf: set)
    }

    public func setWeight(_ weight: Double, of set: SetEntry, carryingTo followers: [SetEntry]) {
        set.weight = weight
        for follower in followers where follower.status != .done { follower.weight = weight }
        commit()
    }

    public func setReps(_ reps: Int, of set: SetEntry) {
        set.reps = reps
        commit()
    }

    public func addSet(to exercise: Exercise) {
        exercise.addSet()
        commit()
    }

    public func deleteSet(_ set: SetEntry, from exercise: Exercise) {
        exercise.remove(set, in: context)
        commit()
    }

    /// In a block the planner prescribes the sets; in a quick workout they prefill from the last time it was done.
    public func addExercise(named name: String, muscle: Muscle, to workout: Workout) {
        MesoPlanner.addExercise(named: name, muscle: muscle, to: workout, unit: unit, snapshot: snapshot, in: context)
        commit()
    }

    public func swapExercise(_ exercise: Exercise, to name: String, muscle: Muscle, scope: PlanScope) {
        MesoPlanner.swap(exercise, to: name, muscle: muscle, scope: scope, unit: unit, snapshot: snapshot, in: context)
        commit()
    }

    public func reorderExercises(of workout: Workout, to exercises: [Exercise], scope: PlanScope) {
        MesoPlanner.reorder(workout, to: exercises, scope: scope)
        commit()
    }

    public func removeExercise(_ exercise: Exercise, from workout: Workout) {
        workout.remove(exercise, in: context)
        commit()
    }

    public func recordSoreness(_ soreness: Soreness, on record: MuscleFeedbackRecord, during workout: Workout) {
        MesoPlanner.recordSoreness(soreness, on: record, during: workout, unit: unit, snapshot: snapshot, in: context)
        commit()
    }

    /// Answers soreness from the muscle's first log tap: re-plans the muscle's sets, then logs the set at the tapped
    /// position with the weight and reps that were entered on it.
    public func recordSoreness(
        _ soreness: Soreness, on record: MuscleFeedbackRecord, during workout: Workout, logging set: SetEntry
    ) {
        let exercise = set.exercise
        let order = set.order
        let (weight, reps) = (set.weight, set.reps)
        MesoPlanner.recordSoreness(soreness, on: record, during: workout, unit: unit, snapshot: snapshot, in: context)
        let replanned = exercise?.sortedSets.first { $0.order == order }
        replanned?.weight = weight
        replanned?.reps = reps
        commit()
        if let replanned { log(replanned, done: true) }
    }

    public func updateFeedback(for muscle: Muscle, in workout: Workout, _ change: (inout MuscleFeedback) -> Void) {
        workout.updateFeedback(for: muscle, change)
        commit()
    }

    public func lastFinishedExercise(_ key: ExerciseID) -> Exercise? {
        MesoPlanner.lastFinishedExercise(key, in: context)
    }

    public func exerciseHistory(_ key: ExerciseID) -> [ExerciseHistoryGroup] {
        observeCommits()
        return ExerciseHistoryGroup.groups(of: key, in: context)
    }

    /// The date each exercise was last done in a finished workout. Exercises never done are missing.
    public func lastPerformed() -> [ExerciseID: Date] {
        observeCommits()
        return ExerciseHistoryGroup.lastPerformed(in: context)
    }

    public func weekStats(now: Date = .now) -> WeekStats {
        observeCommits()
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let thisWeek =
            (try? context.fetch(
                FetchDescriptor<Workout>(predicate: #Predicate { $0.endDate != nil && $0.startDate >= weekStart })))
            ?? []
        return WeekStats(
            thisWeek: thisWeek.count,
            time: thisWeek.reduce(0) { $0 + $1.duration },
            allTime: (try? context.fetchCount(Workout.history)) ?? 0)
    }

    /// Most recently trained exercise first. A session that logs one exercise twice gives one point, its stronger set.
    public func strengthSeries() -> [StrengthSeries] {
        observeCommits()
        var finished = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.endDate != nil }, sortBy: [SortDescriptor(\.startDate)])
        finished.relationshipKeyPathsForPrefetching = [\.storedExercises]
        var byKey: [ExerciseID: (name: String, muscle: Muscle?, points: [StrengthSeries.Point])] = [:]
        for workout in (try? context.fetch(finished)) ?? [] {
            var best: [ExerciseID: (exercise: Exercise, entry: SetEntry, oneRepMax: Double)] = [:]
            for exercise in workout.exercises {
                guard let strongest = exercise.strongestSet,
                    strongest.oneRepMax > best[exercise.key]?.oneRepMax ?? -.infinity
                else { continue }
                best[exercise.key] = (exercise, strongest.entry, strongest.oneRepMax)
            }
            for (key, set) in best {
                let point = StrengthSeries.Point(
                    id: .init(exercise: key, date: workout.startDate), value: set.oneRepMax,
                    bestSet: "\(set.entry.weightText()) × \(set.entry.reps)")
                var series = byKey[key] ?? (name: "", muscle: set.exercise.muscle, points: [])
                series.name = set.exercise.info?.name ?? set.exercise.name
                series.points.append(point)
                byKey[key] = series
            }
        }
        return
            byKey
            .map { StrengthSeries(id: $0.key, name: $0.value.name, muscle: $0.value.muscle, points: $0.value.points) }
            .sorted {
                ($0.points.last?.date ?? .distantPast, $1.id.rawValue) > (
                    $1.points.last?.date ?? .distantPast, $0.id.rawValue
                )
            }
    }

    public func pendingSoreness(in workout: Workout) -> [Muscle: MuscleFeedbackRecord] {
        workout.pendingSoreness
    }

    public func pinnedNote(on exercise: Exercise) -> String? {
        observeCommits()
        return PinnedNote.find(named: exercise.name, in: context)?.text
    }

    public func finish(_ workout: Workout) {
        workout.finish(in: context)
        commit()
    }

    public func delete(_ workout: Workout) {
        workout.mesocycle?.workouts.removeAll { $0 === workout }
        context.delete(workout)
        commit()
    }

    @discardableResult
    public func startQuickWorkout() -> Workout {
        let workout = Workout(name: Self.defaultWorkoutName())
        context.insert(workout)
        workout.bodyweight = snapshot.bodyweight
        commit()
        return workout
    }

    /// A weight of 0 or less, or nil, clears it.
    public func setBodyweight(_ weight: Double?, of workout: Workout) {
        workout.setBodyweight(weight)
        commit()
    }

    public func setNote(_ text: String, on workout: Workout, pinned: Bool) {
        workout.setNote(text, pinned: pinned)
        commit()
    }

    public func setNote(_ text: String, on exercise: Exercise) {
        exercise.setNote(text, in: context)
        commit()
    }

    public func deleteNote(on exercise: Exercise) {
        exercise.deleteNote(in: context)
        commit()
    }

    public func pinNote(on exercise: Exercise) {
        exercise.pinNote(in: context)
        commit()
    }

    public func unpinNote(on exercise: Exercise) {
        exercise.unpinNote(in: context)
        commit()
    }

    public func dismissFailure() {
        failure = nil
    }

    @discardableResult
    func backfillExerciseKeys() -> Int {
        let exercises =
            (try? context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.exerciseKey == nil }))) ?? []
        for exercise in exercises { exercise.exerciseKey = ExerciseID(folding: exercise.name).rawValue }
        let slots =
            (try? context.fetch(FetchDescriptor<DaySlot>(predicate: #Predicate { $0.exerciseKey == nil }))) ?? []
        for slot in slots { slot.exerciseKey = ExerciseID(folding: slot.exerciseName).rawValue }
        let written = exercises.count + slots.count
        if written > 0 { commit() }
        return written
    }

    func observeCommits() {
        _ = revision
    }

    func commit() {
        cachedSnapshot = nil
        do {
            try context.save()
            revision += 1
        } catch {
            failure = error
        }
    }

    private static func defaultWorkoutName() -> String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Morning Workout"
        case 12..<17: "Afternoon Workout"
        default: "Evening Workout"
        }
    }
}

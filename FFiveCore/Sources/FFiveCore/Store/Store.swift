import Foundation
import Observation
import SwiftData

public enum StoreError: Error, Equatable {
    case anotherMesocycleIsActive
}

@MainActor
@Observable
public final class Store {
    public let container: ModelContainer
    public let settings: Settings
    let context: ModelContext
    public private(set) var revision = 0
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
    }

    public convenience init(inMemory: Bool) {
        self.init(inMemory: inMemory, settings: Settings())
    }

    private var unit: WeightUnit { settings.weightUnit }

    /// Dropped by every commit, saved or not, because the context holds the change either way.
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

    public func skip(_ key: SessionKey, of meso: Mesocycle) {
        meso.skip(key, in: context)
        commit()
    }

    public func unskip(_ key: SessionKey, of meso: Mesocycle) {
        meso.unskip(key)
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
    public func log(_ set: SetEntry, done: Bool) {
        if done, let workout = set.exercise?.workout, workout.mesocycle != nil, workout.completedSets == 0 {
            workout.startDate = .now
        }
        set.isDone = done
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

    public func swapExercise(_ exercise: Exercise, to name: String, muscle: Muscle) {
        MesoPlanner.swap(exercise, to: name, muscle: muscle, unit: unit, snapshot: snapshot, in: context)
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

    public func lastFinishedExercise(_ key: ExerciseID) -> Exercise? {
        MesoPlanner.lastFinishedExercise(key, in: context)
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
        commit()
        return workout
    }

    public func setNote(_ text: String, on workout: Workout) {
        workout.setNote(text)
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

    /// Rows written before the key column existed get their folded name, once per store.
    @discardableResult
    func backfillExerciseKeys() -> Int {
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.exerciseKey == nil }))) ?? []
        for exercise in exercises { exercise.exerciseKey = ExerciseID(folding: exercise.name).rawValue }
        let slots = (try? context.fetch(FetchDescriptor<DaySlot>(predicate: #Predicate { $0.exerciseKey == nil }))) ?? []
        for slot in slots { slot.exerciseKey = ExerciseID(folding: slot.exerciseName).rawValue }
        let written = exercises.count + slots.count
        if written > 0 { commit() }
        return written
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

import Foundation
import SwiftData

/// What the lifter edits in the builder before a mesocycle exists.
public struct MesoDraft {
    public struct Slot: Identifiable, Hashable {
        public let id = UUID()
        public var exercise: String
        public var muscle: Muscle

        public init(exercise: String, muscle: Muscle) {
            self.exercise = exercise
            self.muscle = muscle
        }
    }

    public struct Day: Identifiable, Hashable {
        public let id = UUID()
        public var name: String
        public var slots: [Slot]

        public init(name: String, slots: [Slot]) {
            self.name = name
            self.slots = slots
        }
    }

    public var name: String
    public var accumulationWeeks = 4
    public var days: [Day]

    public init(template: ProgramTemplate?) {
        name = template?.name ?? "My Mesocycle"
        days =
            template?.days.map { day in
                Day(name: day.name, slots: day.slots.map { Slot(exercise: $0.exercise, muscle: $0.muscle) })
            } ?? [Day(name: "Day 1", slots: [])]
    }

    public var isStartable: Bool { days.contains { !$0.slots.isEmpty } }
}

public struct PlannedExercise {
    public let name: String
    let key: ExerciseID
    public let muscle: Muscle?
    let targets: [SetTarget]
}

public struct MuscleVolume: Identifiable {
    public let muscle: Muscle
    public let done: Int
    public let planned: Int
    public var id: Muscle { muscle }
}

extension ExerciseCatalog {
    public static func repRange(for id: ExerciseID) -> ClosedRange<Int> { info(id)?.repRange ?? 8...12 }

    static func increment(for id: ExerciseID, unit: WeightUnit) -> Double {
        (info(id)?.equipment ?? .machine).increment(unit)
    }
}

/// Owns every decision about what a mesocycle session prescribes.
@MainActor
enum MesoPlanner {
    /// Deload sessions and exercises added during one load at the easiest accumulation effort.
    private static let deloadRIR = 3

    @discardableResult
    static func start(_ draft: MesoDraft, in context: ModelContext) -> Mesocycle {
        let meso = Mesocycle(
            name: draft.name.trimmingCharacters(in: .whitespaces).isEmpty ? "My Mesocycle" : draft.name,
            accumulationWeeks: draft.accumulationWeeks)
        context.insert(meso)
        for (order, draftDay) in draft.days.filter({ !$0.slots.isEmpty }).enumerated() {
            let day = MesoDay(name: draftDay.name, order: order)
            meso.days.append(day)
            for (slotOrder, slot) in draftDay.slots.enumerated() {
                day.slots.append(DaySlot(exerciseName: slot.exercise, muscle: slot.muscle, order: slotOrder))
            }
        }
        return meso
    }

    /// The session for `key`, built from the plan the first time it is asked for.
    static func workout(
        for meso: Mesocycle, at key: SessionKey, unit: WeightUnit, snapshot: PlanningSnapshot,
        in context: ModelContext
    ) -> Workout {
        if let existing = meso.workout(at: key) { return existing }
        let planned = plan(meso, at: key, unit: unit, snapshot: snapshot)
        let days = meso.sortedDays
        let workout = Workout(
            name: days.indices.contains(key.dayIndex) ? days[key.dayIndex].name : "Day \(key.dayIndex + 1)")
        context.insert(workout)
        workout.week = key.week
        workout.dayIndex = key.dayIndex
        meso.workouts.append(workout)
        for (order, exercise) in planned.enumerated() {
            let model = Exercise(name: exercise.name, order: order, muscle: exercise.muscle)
            workout.exercises.append(model)
            replaceSets(of: model, with: exercise.targets, in: context)
        }
        return workout
    }

    /// What the session at `key` would prescribe if it were built now. Reads only; never inserts.
    static func plan(_ meso: Mesocycle, at key: SessionKey, unit: WeightUnit, snapshot: PlanningSnapshot)
        -> [PlannedExercise]
    {
        let base = meso.latestWorkout(dayIndex: key.dayIndex, before: key.week)
        switch meso.phase(week: key.week) {
        case .deload:
            guard let base else {
                return templatePlan(meso, dayIndex: key.dayIndex, rir: deloadRIR, unit: unit, snapshot: snapshot).map {
                    PlannedExercise(
                        name: $0.name, key: $0.key, muscle: $0.muscle,
                        targets: Progression.deloadTargets(
                            firstWeek: $0.targets, lastAccumulationSetCount: $0.targets.count))
                }
            }
            return base.sortedExercises.map { exercise in
                PlannedExercise(
                    name: exercise.name, key: exercise.key, muscle: exercise.muscle,
                    targets: Progression.deloadTargets(
                        firstWeek: firstWeekTargets(of: exercise.key, dayIndex: key.dayIndex, in: meso),
                        lastAccumulationSetCount: exercise.sets.count))
            }
        case .accumulation(let rir):
            guard let base, let baseRIR = base.phase?.rir else {
                return templatePlan(meso, dayIndex: key.dayIndex, rir: rir, unit: unit, snapshot: snapshot)
            }
            return progressedPlan(from: base, baseRIR: baseRIR, meso: meso, key: key, rir: rir, unit: unit)
        }
    }

    // MARK: - Plans

    private static func templatePlan(
        _ meso: Mesocycle, dayIndex: Int, rir: Int, unit: WeightUnit, snapshot: PlanningSnapshot
    ) -> [PlannedExercise] {
        let days = meso.sortedDays
        guard days.indices.contains(dayIndex) else { return [] }
        return days[dayIndex].sortedSlots.map { slot in
            PlannedExercise(
                name: slot.exerciseName, key: slot.key, muscle: slot.muscle,
                targets: freshTargets(
                    for: slot.key,
                    count: initialSetCount(of: slot, dayIndex: dayIndex, in: meso),
                    rir: rir, unit: unit, snapshot: snapshot))
        }
    }

    private static func progressedPlan(
        from base: Workout, baseRIR: Int, meso: Mesocycle, key: SessionKey,
        rir: Int, unit: WeightUnit
    ) -> [PlannedExercise] {
        let exercises = base.sortedExercises
        var counts = exercises.map { max(1, $0.sets.count) }
        for muscle in base.trainedMuscles {
            let indices = exercises.indices.filter { exercises[$0].muscle == muscle }
            let delta = Progression.setDelta(base.feedbackRecord(for: muscle)?.value ?? MuscleFeedback())
            let projected =
                projectedSets(of: muscle, in: meso, week: key.week, excludingDay: key.dayIndex)
                + base.setCount(for: muscle)
            let spread = Progression.distribute(
                delta: delta, across: indices.map { counts[$0] },
                weeklyRoom: muscle.landmarks.mrv - projected)
            for (position, index) in indices.enumerated() { counts[index] = spread[position] }
        }
        return exercises.indices.map { index in
            let exercise = exercises[index]
            let sets = exercise.sortedSets
            return PlannedExercise(
                name: exercise.name, key: exercise.key, muscle: exercise.muscle,
                targets: Progression.nextTargets(
                    previousTargets: sets.map(\.target),
                    logged: sets.map(\.logged),
                    previousRIR: baseRIR,
                    targetRIR: rir,
                    repRange: exercise.repRange,
                    increment: exercise.increment(unit),
                    setCount: counts[index]))
        }
    }

    /// Sets of `muscle` in `week` across the other days, counting a day not yet built at its latest session's size.
    /// Using this week's built days, not only last week's total, keeps two days from both spending the same room.
    private static func projectedSets(of muscle: Muscle, in meso: Mesocycle, week: Int, excludingDay: Int) -> Int {
        meso.days.indices.filter { $0 != excludingDay }.reduce(0) { total, day in
            if meso.status(at: SessionKey(week: week, dayIndex: day)) == .skipped { return total }
            if let workout = meso.workout(at: SessionKey(week: week, dayIndex: day))
                ?? meso.latestWorkout(dayIndex: day, before: week)
            {
                return total + workout.setCount(for: muscle)
            }
            let slots = meso.sortedDays.indices.contains(day) ? meso.sortedDays[day].slots : []
            return total
                + slots.filter { $0.muscle == muscle }.reduce(0) {
                    $0 + initialSetCount(of: $1, dayIndex: day, in: meso)
                }
        }
    }

    private static func initialSetCount(of slot: DaySlot, dayIndex: Int, in meso: Mesocycle) -> Int {
        guard let muscle = slot.muscle else { return 2 }
        let sessions = meso.days.filter { $0.slots.contains { $0.muscleRaw == slot.muscleRaw } }.count
        let inSession = meso.sortedDays[dayIndex].slots.filter { $0.muscleRaw == slot.muscleRaw }.count
        return Progression.initialSetsPerExercise(
            muscle: muscle, sessionsPerWeek: sessions, exercisesInSession: inSession)
    }

    /// Targets for an exercise with no history in this block: solved from the lifter's latest logged sets
    /// anywhere, or calibrate when there are none.
    private static func freshTargets(
        for key: ExerciseID, count: Int, rir: Int, unit: WeightUnit, snapshot: PlanningSnapshot
    ) -> [SetTarget] {
        guard let oneRepMax = snapshot.latestOneRepMax(of: key) else {
            return Array(repeating: .calibrate, count: count)
        }
        let reps = Progression.startingReps(in: ExerciseCatalog.repRange(for: key))
        let load = Progression.load(
            forReps: reps, rir: rir, oneRepMax: oneRepMax,
            increment: ExerciseCatalog.increment(for: key, unit: unit))
        return Array(repeating: load > 0 ? SetTarget(weight: load, reps: reps) : .calibrate, count: count)
    }

    /// The loads and reps this exercise was first done at in the block, preferring the same day.
    private static func firstWeekTargets(of key: ExerciseID, dayIndex: Int, in meso: Mesocycle) -> [SetTarget] {
        let candidates = meso.workouts.filter { $0.phase?.rir != nil && $0.exercises.contains { $0.key == key } }
        let earliest: (Workout, Workout) -> Bool = { ($0.week ?? .max) < ($1.week ?? .max) }
        guard
            let workout = candidates.filter({ $0.dayIndex == dayIndex }).min(by: earliest)
                ?? candidates.min(by: earliest),
            let exercise = workout.sortedExercises.first(where: { $0.key == key })
        else { return [] }
        return exercise.sortedSets.map { set in
            SetTarget(
                weight: set.targetWeight ?? (set.isDone ? set.weight : nil),
                reps: set.targetReps ?? (set.isDone ? set.reps : nil))
        }
    }

    // MARK: - Session edits

    static func addExercise(
        named name: String, muscle: Muscle, to workout: Workout, unit: WeightUnit,
        snapshot: PlanningSnapshot, in context: ModelContext
    ) {
        let exercise = Exercise(name: name, order: (workout.exercises.map(\.order).max() ?? -1) + 1, muscle: muscle)
        workout.exercises.append(exercise)
        guard let meso = workout.mesocycle else {
            let previous = lastFinishedExercise(exercise.key, in: context)?.sortedSets.filter(\.isDone) ?? []
            if previous.isEmpty {
                exercise.sets.append(SetEntry(reps: 10, weight: 0, order: 0))
            } else {
                for (order, set) in previous.enumerated() {
                    let copy = SetEntry(reps: set.reps, weight: set.weight, order: order)
                    copy.type = set.type
                    exercise.sets.append(copy)
                }
            }
            return
        }
        let sessions = meso.days.filter { $0.slots.contains { $0.muscleRaw == muscle.rawValue } }.count
        let count = Progression.initialSetsPerExercise(
            muscle: muscle, sessionsPerWeek: sessions,
            exercisesInSession: workout.exercises(for: muscle).count)
        replaceSets(
            of: exercise,
            with: freshTargets(
                for: exercise.key, count: count, rir: workout.phase?.rir ?? deloadRIR,
                unit: unit, snapshot: snapshot), in: context)
    }

    static func lastFinishedExercise(_ key: ExerciseID, in context: ModelContext) -> Exercise? {
        let raw = key.rawValue
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.exerciseKey == raw })
        return ((try? context.fetch(descriptor)) ?? [])
            .filter { $0.workout?.endDate != nil }
            .max { ($0.workout?.startDate ?? .distantPast) < ($1.workout?.startDate ?? .distantPast) }
    }

    /// Swaps an untouched exercise for another, keeping its set count and re-deriving targets.
    static func swap(
        _ exercise: Exercise, to name: String, muscle: Muscle, unit: WeightUnit,
        snapshot: PlanningSnapshot, in context: ModelContext
    ) {
        exercise.rename(name)
        exercise.muscle = muscle
        guard let workout = exercise.workout, workout.mesocycle != nil else { return }
        replaceSets(
            of: exercise,
            with: freshTargets(
                for: exercise.key, count: max(1, exercise.sets.count),
                rir: workout.phase?.rir ?? deloadRIR, unit: unit, snapshot: snapshot),
            in: context)
    }

    private static func replaceSets(of exercise: Exercise, with targets: [SetTarget], in context: ModelContext) {
        let old = exercise.sets
        exercise.sets.removeAll()
        old.forEach(context.delete)
        for (order, target) in targets.enumerated() {
            exercise.sets.append(SetEntry(target: target, order: order))
        }
    }

    // MARK: - Feedback

    /// Writes soreness back to the session it describes. When that session is the one this session was planned
    /// from and the muscle is still untouched, its set count is re-planned with the now-complete feedback.
    static func recordSoreness(
        _ soreness: Soreness, on record: MuscleFeedbackRecord, during workout: Workout,
        unit: WeightUnit, snapshot: PlanningSnapshot, in context: ModelContext
    ) {
        record.value.soreness = soreness
        guard let muscle = record.muscle, let meso = workout.mesocycle, let key = workout.key,
            let base = meso.latestWorkout(dayIndex: key.dayIndex, before: key.week), base === record.workout,
            !workout.exercises(for: muscle).contains(where: { $0.sets.contains(where: \.isDone) })
        else { return }
        let planned = plan(meso, at: key, unit: unit, snapshot: snapshot)
        for exercise in workout.exercises(for: muscle) {
            guard let match = planned.first(where: { $0.key == exercise.key && $0.muscle == muscle }) else { continue }
            replaceSets(of: exercise, with: match.targets, in: context)
        }
    }

    // MARK: - Volume

    /// Done and planned sets per muscle for one week. Days not built yet count at what they would prescribe,
    /// skipped days count nothing.
    static func weeklyVolume(_ meso: Mesocycle, week: Int, unit: WeightUnit, snapshot: PlanningSnapshot)
        -> [MuscleVolume]
    {
        var done: [Muscle: Int] = [:]
        var planned: [Muscle: Int] = [:]
        for day in meso.days.indices {
            let key = SessionKey(week: week, dayIndex: day)
            switch meso.status(at: key) {
            case .skipped:
                continue
            case .inProgress(let workout), .finished(let workout):
                for exercise in workout.exercises {
                    guard let muscle = exercise.muscle else { continue }
                    planned[muscle, default: 0] += exercise.sets.count
                    done[muscle, default: 0] += exercise.sets.filter(\.isDone).count
                }
            case .upcoming:
                for exercise in plan(meso, at: key, unit: unit, snapshot: snapshot) {
                    guard let muscle = exercise.muscle else { continue }
                    planned[muscle, default: 0] += exercise.targets.count
                }
            }
        }
        return Muscle.allCases
            .filter { planned[$0] != nil || done[$0] != nil }
            .map { MuscleVolume(muscle: $0, done: done[$0] ?? 0, planned: planned[$0] ?? 0) }
    }
}

import Foundation
import SwiftData

public struct MesoDraft: Equatable {
    /// A muscle trained on a day, with the exercise for it once one is chosen.
    public struct Slot: Identifiable, Hashable {
        public let id = UUID()
        /// Changing the exercise drops the starting targets, which were logged on the old one.
        public var exercise: String? {
            didSet { if exercise != oldValue { startingTargets = nil } }
        }
        public var muscle: Muscle
        /// The first session's sets, carried from a recent block this draft copies. Nil plans them fresh.
        public internal(set) var startingTargets: [SetTarget]?

        public init(exercise: String? = nil, muscle: Muscle) {
            self.exercise = exercise
            self.muscle = muscle
        }

        init(exercise: String, muscle: Muscle, startingTargets: [SetTarget]?) {
            self.init(exercise: exercise, muscle: muscle)
            self.startingTargets = startingTargets
        }
    }

    public struct Day: Identifiable, Hashable {
        public let id = UUID()
        public var name: String
        public var weekday: Weekday?
        public var slots: [Slot]

        public init(name: String, weekday: Weekday? = nil, slots: [Slot]) {
            self.name = name
            self.weekday = weekday
            self.slots = slots
        }
    }

    public var name: String
    public var accumulationWeeks = 4
    public var days: [Day]
    /// A muscle missing here is trained at normal priority.
    public var priorities: [Muscle: MusclePriority] = [:]
    /// The weekday the block's first day falls on, once chosen. It only seeds the days' weekday labels.
    public private(set) var startWeekday: Weekday?

    public init(template: ProgramTemplate?) {
        name = template?.name ?? "My Mesocycle"
        days =
            template?.days.map { day in
                Day(name: day.name, slots: day.slots.map { Slot(exercise: $0.exercise, muscle: $0.muscle) })
            } ?? [Day(name: "Day 1", slots: [])]
    }

    /// Starts the block on `start` and labels every day with a suggested weekday that spreads rest through the week.
    public mutating func schedule(startingOn start: Weekday) {
        startWeekday = start
        for (index, weekday) in Weekday.suggested(days: days.count, startingOn: start).enumerated() {
            days[index].weekday = weekday
        }
    }

    public var isStartable: Bool { days.contains { !$0.slots.isEmpty } && !hasEmptySlot }

    public var hasEmptySlot: Bool { days.contains { $0.slots.contains { $0.exercise == nil } } }

    /// Every muscle a day of the draft trains, in catalog order.
    public var muscles: [Muscle] {
        let trained = Set(days.flatMap(\.slots).map(\.muscle))
        return Muscle.allCases.filter(trained.contains)
    }

    /// Moves the days at `offsets` to just before the day now at `destination`, as `List.onMove` reports a drag.
    /// A day keeps its name, weekday and slots, and the block trains its days in this order.
    public mutating func moveDays(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        let moving = offsets.map { days[$0] }
        let shift = offsets.filter { $0 < destination }.count
        days = days.indices.filter { !offsets.contains($0) }.map { days[$0] }
        days.insert(contentsOf: moving, at: destination - shift)
    }
}

/// Whether a change to a block session stays in it or is handed on to later weeks of its day.
public enum PlanScope {
    case thisSession
    case laterWeeks
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
    static func repRange(for id: ExerciseID) -> ClosedRange<Int> { info(id)?.repRange ?? 8...12 }

}

/// What planning reads besides the block itself: the lifter's weight unit and what they have lifted before.
struct PlanningContext {
    let unit: WeightUnit
    let snapshot: PlanningSnapshot

    /// The next session's targets for `exercise`, logged at `previousRIR`, aiming at `rir` over `setCount` sets.
    fileprivate func nextTargets(
        after exercise: Exercise, at previousRIR: Int, rir: Int, setCount: Int, bodyweight: Double?
    ) -> [SetTarget] {
        let sets = exercise.sortedSets
        let loading = snapshot.loading(for: exercise.key, bodyweight: bodyweight)
        return Progression.nextTargets(
            previousTargets: sets.map(\.target),
            logged: sets.map(\.logged),
            previousRIR: previousRIR,
            targetRIR: rir,
            repRange: snapshot.repRange(for: exercise.key),
            increment: loading.increment(unit),
            offset: loading.offset ?? 0,
            setCount: setCount)
    }

    /// Targets for a lift with no earlier session in the block, from its latest one-rep max when there is one.
    fileprivate func freshTargets(for key: ExerciseID, count: Int, rir: Int, bodyweight: Double?) -> [SetTarget] {
        let loading = snapshot.loading(for: key, bodyweight: bodyweight)
        guard let offset = loading.offset, let oneRepMax = snapshot.latestOneRepMax(of: key) else {
            return Array(repeating: .calibrate, count: count)
        }
        let reps = Progression.startingReps(in: snapshot.repRange(for: key))
        let load = Progression.load(
            forReps: reps, rir: rir, oneRepMax: oneRepMax, increment: loading.increment(unit), offset: offset)
        return Array(repeating: load + offset > 0 ? SetTarget(weight: load, reps: reps) : .calibrate, count: count)
    }

    /// Fresh targets for a lift added to `workout`, at its effort and body weight.
    fileprivate func freshTargets(for key: ExerciseID, count: Int, in workout: Workout) -> [SetTarget] {
        freshTargets(
            for: key, count: count, rir: workout.phase?.rir ?? MesoPlanner.deloadRIR,
            bodyweight: workout.bodyweight ?? snapshot.bodyweight)
    }
}

@MainActor
enum MesoPlanner {
    /// Deload sessions and exercises added during one load at the easiest accumulation effort.
    fileprivate static let deloadRIR = 3

    @discardableResult
    static func start(_ draft: MesoDraft, in context: ModelContext) -> Mesocycle {
        let meso = Mesocycle(
            name: draft.name.trimmed(or: "My Mesocycle"), accumulationWeeks: draft.accumulationWeeks)
        context.insert(meso)
        for muscle in draft.muscles { meso.setPriority(draft.priorities[muscle] ?? .normal, of: muscle) }
        for (order, draftDay) in draft.days.filter({ !$0.slots.isEmpty }).enumerated() {
            let day = MesoDay(
                name: draftDay.name.trimmed(or: "Day \(order + 1)"), order: order, weekday: draftDay.weekday)
            meso.days.append(day)
            for (slotOrder, slot) in draftDay.slots.enumerated() {
                guard let exercise = slot.exercise else { continue }
                CustomExercise.ensure(named: exercise, muscle: slot.muscle, in: context)
                let daySlot = DaySlot(exerciseName: exercise, muscle: slot.muscle, order: slotOrder)
                daySlot.startingTargets = slot.startingTargets
                day.slots.append(daySlot)
            }
        }
        return meso
    }

    /// The session for `key`, built from the plan the first time it is asked for.
    static func workout(
        for meso: Mesocycle, at key: SessionKey, planning: PlanningContext, in context: ModelContext
    ) -> Workout {
        if let existing = meso.workout(at: key) { return existing }
        let planned = plan(meso, at: key, planning: planning)
        let day = meso.day(at: key.dayIndex)
        let workout = Workout(name: day?.name ?? "Day \(key.dayIndex + 1)")
        context.insert(workout)
        workout.weekday = day?.weekday
        workout.week = key.week
        workout.dayIndex = key.dayIndex
        workout.bodyweight = planning.snapshot.bodyweight
        meso.workouts.append(workout)
        fill(workout, with: planned, in: context)
        return workout
    }

    /// Replaces a built session's exercises with what the plan prescribes now, keeping the session itself so a
    /// screen showing it stays put.
    static func rebuild(_ workout: Workout, planning: PlanningContext, in context: ModelContext) {
        guard let meso = workout.mesocycle, let key = workout.key else { return }
        let planned = plan(meso, at: key, planning: planning)
        for exercise in workout.exercises { workout.remove(exercise, in: context) }
        fill(workout, with: planned, in: context)
    }

    private static func fill(_ workout: Workout, with planned: [PlannedExercise], in context: ModelContext) {
        for (order, exercise) in planned.enumerated() {
            let model = Exercise(name: exercise.name, order: order, muscle: exercise.muscle)
            workout.exercises.append(model)
            replaceSets(of: model, with: exercise.targets, in: context)
        }
    }

    /// What the session at `key` would prescribe if it were built now. Reads only; never inserts.
    static func plan(_ meso: Mesocycle, at key: SessionKey, planning: PlanningContext) -> [PlannedExercise] {
        let base = meso.latestWorkout(dayIndex: key.dayIndex, before: key.week)
        switch meso.phase(week: key.week) {
        case .deload:
            guard let base else {
                return templatePlan(meso, dayIndex: key.dayIndex, rir: deloadRIR, planning: planning).map {
                    PlannedExercise(
                        name: $0.name, key: $0.key, muscle: $0.muscle,
                        targets: Progression.deloadTargets(
                            firstWeek: $0.targets, lastAccumulationSetCount: $0.targets.count))
                }
            }
            return base.plannedExercises.map { exercise in
                let planned = exercise.planned
                return PlannedExercise(
                    name: planned.name, key: planned.key, muscle: planned.muscle,
                    targets: Progression.deloadTargets(
                        firstWeek: firstWeekTargets(of: planned.key, dayIndex: key.dayIndex, in: meso),
                        lastAccumulationSetCount: exercise.sets.count))
            }
        case .accumulation(let rir):
            guard let base, let baseRIR = base.phase?.rir else {
                return templatePlan(meso, dayIndex: key.dayIndex, rir: rir, planning: planning)
            }
            return progressedPlan(from: base, baseRIR: baseRIR, meso: meso, key: key, rir: rir, planning: planning)
        }
    }

    private static func templatePlan(_ meso: Mesocycle, dayIndex: Int, rir: Int, planning: PlanningContext)
        -> [PlannedExercise]
    {
        guard let day = meso.day(at: dayIndex) else { return [] }
        return day.sortedSlots.map { slot in
            PlannedExercise(
                name: slot.exerciseName, key: slot.key, muscle: slot.muscle,
                targets: slot.startingTargets
                    ?? planning.freshTargets(
                        for: slot.key, count: initialSetCount(of: slot, dayIndex: dayIndex, in: meso), rir: rir,
                        bodyweight: planning.snapshot.bodyweight))
        }
    }

    private static func progressedPlan(
        from base: Workout, baseRIR: Int, meso: Mesocycle, key: SessionKey,
        rir: Int, planning: PlanningContext
    ) -> [PlannedExercise] {
        let bodyweight = base.bodyweight ?? planning.snapshot.bodyweight
        let exercises = base.plannedExercises
        var counts = exercises.map { max(1, $0.sets.count) }
        for muscle in base.trainedMuscles {
            let indices = exercises.indices.filter { exercises[$0].muscle == muscle }
            let delta = Progression.setDelta(
                base.feedbackRecord(for: muscle)?.value ?? MuscleFeedback(), priority: meso.priority(of: muscle))
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
            let planned = exercise.planned
            let targets: [SetTarget]
            if planned.key == exercise.key {
                targets = planning.nextTargets(
                    after: exercise, at: baseRIR, rir: rir, setCount: counts[index], bodyweight: bodyweight)
            } else if let (previous, previousRIR) = latestExercise(planned.key, before: base, in: meso) {
                targets = planning.nextTargets(
                    after: previous, at: previousRIR, rir: rir, setCount: counts[index], bodyweight: bodyweight)
            } else {
                targets = planning.freshTargets(
                    for: planned.key, count: counts[index], rir: rir, bodyweight: bodyweight)
            }
            return PlannedExercise(name: planned.name, key: planned.key, muscle: planned.muscle, targets: targets)
        }
    }

    /// The latest accumulation session of `base`'s day before it that did `key`, so a lift a session-only swap
    /// set aside picks up where it left off.
    private static func latestExercise(_ key: ExerciseID, before base: Workout, in meso: Mesocycle)
        -> (Exercise, rir: Int)?
    {
        meso.workouts
            .filter { $0.dayIndex == base.dayIndex && ($0.week ?? .max) < (base.week ?? 0) }
            .sorted { ($0.week ?? 0) > ($1.week ?? 0) }
            .lazy
            .compactMap { workout in
                guard let rir = workout.phase?.rir, let exercise = workout.exercises.first(where: { $0.key == key })
                else { return nil }
                return (exercise, rir)
            }
            .first
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
            let slots = meso.day(at: day)?.slots ?? []
            return total
                + slots.filter { $0.muscle == muscle }.reduce(0) {
                    $0 + initialSetCount(of: $1, dayIndex: day, in: meso)
                }
        }
    }

    private static func initialSetCount(of slot: DaySlot, dayIndex: Int, in meso: Mesocycle) -> Int {
        if let carried = slot.startingTargets { return carried.count }
        guard let muscle = slot.muscle else { return 2 }
        let inSession = (meso.day(at: dayIndex)?.slots ?? []).filter { $0.muscleRaw == slot.muscleRaw }.count
        return initialSetCount(of: muscle, exercisesInSession: inSession, in: meso)
    }

    private static func initialSetCount(of muscle: Muscle, exercisesInSession: Int, in meso: Mesocycle) -> Int {
        let sessions = meso.days.filter { $0.slots.contains { $0.muscleRaw == muscle.rawValue } }.count
        return Progression.initialSetsPerExercise(
            muscle: muscle, priority: meso.priority(of: muscle), sessionsPerWeek: sessions,
            exercisesInSession: exercisesInSession)
    }

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

    static func addExercise(
        named name: String, muscle: Muscle, to workout: Workout, planning: PlanningContext, in context: ModelContext
    ) {
        let exercise = Exercise(name: name, order: (workout.exercises.map(\.order).max() ?? -1) + 1, muscle: muscle)
        workout.exercises.append(exercise)
        CustomExercise.ensure(named: name, muscle: muscle, in: context)
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
        let count = initialSetCount(of: muscle, exercisesInSession: workout.exercises(for: muscle).count, in: meso)
        replaceSets(
            of: exercise, with: planning.freshTargets(for: exercise.key, count: count, in: workout), in: context)
    }

    static func lastFinishedExercise(_ key: ExerciseID, in context: ModelContext) -> Exercise? {
        let raw = key.rawValue
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.exerciseKey == raw })
        return ((try? context.fetch(descriptor)) ?? [])
            .filter { $0.workout?.endDate != nil }
            .max { ($0.workout?.startDate ?? .distantPast) < ($1.workout?.startDate ?? .distantPast) }
    }

    /// Swaps an untouched exercise for another, keeping its set count and re-deriving targets.
    /// In a block, `.thisSession` keeps the old exercise for later weeks and `.laterWeeks` hands the new one on,
    /// including to the same exercise in later same-day sessions that are built but not started.
    static func swap(
        _ exercise: Exercise, to name: String, muscle: Muscle, scope: PlanScope, planning: PlanningContext,
        in context: ModelContext
    ) {
        let original = exercise.key
        let meso = exercise.workout?.mesocycle
        if meso != nil, scope == .thisSession, exercise.plannedName == nil {
            exercise.plannedName = exercise.name
            exercise.plannedMuscleRaw = exercise.muscle?.rawValue
        }
        replace(exercise, with: name, muscle: muscle, planning: planning, in: context)
        if meso == nil || scope == .laterWeeks || exercise.planned.key == exercise.key { exercise.clearPlanned() }
        guard let meso, scope == .laterWeeks, let key = exercise.workout?.key else { return }
        for later in meso.laterOpenSessions(after: key) {
            for match in later.exercises where match.key == original && !match.sets.contains(where: \.isDone) {
                replace(match, with: name, muscle: muscle, planning: planning, in: context)
                match.clearPlanned()
            }
        }
    }

    private static func replace(
        _ exercise: Exercise, with name: String, muscle: Muscle, planning: PlanningContext, in context: ModelContext
    ) {
        exercise.rename(name)
        exercise.muscle = muscle
        CustomExercise.ensure(named: name, muscle: muscle, in: context)
        guard let workout = exercise.workout, workout.mesocycle != nil else { return }
        replaceSets(
            of: exercise,
            with: planning.freshTargets(for: exercise.key, count: max(1, exercise.sets.count), in: workout),
            in: context)
    }

    /// Puts `workout`'s exercises in the order of `exercises`. Exercises left out of the list follow the listed ones.
    /// In a block, `.thisSession` keeps the old order for later weeks and `.laterWeeks` hands the new one on,
    /// including to later same-day sessions that are built but not finished.
    static func reorder(_ workout: Workout, to exercises: [Exercise], scope: PlanScope) {
        var seen = Set<ObjectIdentifier>()
        let listed = exercises.filter { workout.exercises.contains($0) && seen.insert(ObjectIdentifier($0)).inserted }
        let ordered = listed + workout.sortedExercises.filter { !seen.contains(ObjectIdentifier($0)) }
        let carriesForward = workout.mesocycle != nil && scope == .thisSession
        for (index, exercise) in ordered.enumerated() {
            if carriesForward, exercise.plannedOrder == nil { exercise.plannedOrder = exercise.order }
            if !carriesForward { exercise.plannedOrder = nil }
            exercise.order = index
        }
        guard let meso = workout.mesocycle, scope == .laterWeeks, let key = workout.key else { return }
        let keys = ordered.map(\.key)
        for later in meso.laterOpenSessions(after: key) {
            let rank = { (exercise: Exercise) in keys.firstIndex(of: exercise.key) ?? keys.count }
            let following = later.sortedExercises.enumerated().sorted {
                (rank($0.element), $0.offset) < (rank($1.element), $1.offset)
            }
            for (index, entry) in following.enumerated() {
                entry.element.order = index
                entry.element.plannedOrder = nil
            }
        }
    }

    private static func replaceSets(of exercise: Exercise, with targets: [SetTarget], in context: ModelContext) {
        let old = exercise.sets
        exercise.sets.removeAll()
        old.forEach(context.delete)
        for (order, target) in targets.enumerated() {
            exercise.sets.append(SetEntry(target: target, order: order))
        }
    }

    /// Writes soreness back to the session it describes. When that session is the one this session was planned
    /// from and the muscle is still untouched, the answer changes only how many sets each of its exercises has:
    /// the sets the lifter already has keep their weight, reps and type. `kept` is never removed.
    static func recordSoreness(
        _ soreness: Soreness, on record: MuscleFeedbackRecord, during workout: Workout,
        planning: PlanningContext, keeping kept: SetEntry? = nil, in context: ModelContext
    ) {
        guard let muscle = record.muscle, let meso = workout.mesocycle, let key = workout.key,
            let base = meso.latestWorkout(dayIndex: key.dayIndex, before: key.week), base === record.workout,
            !workout.exercises(for: muscle).contains(where: { $0.sets.contains(where: \.isDone) })
        else {
            record.value.soreness = soreness
            return
        }
        let before = plan(meso, at: key, planning: planning)
        record.value.soreness = soreness
        let after = plan(meso, at: key, planning: planning)
        let targets = { (plan: [PlannedExercise], exercise: Exercise) in
            plan.first { $0.key == exercise.key && $0.muscle == muscle }?.targets
        }
        for exercise in workout.exercises(for: muscle) {
            guard let old = targets(before, exercise), let new = targets(after, exercise) else { continue }
            resize(exercise, by: new.count - old.count, toward: new, keeping: kept, in: context)
        }
    }

    /// Adds `delta` sets from the end of `targets`, or removes `-delta` sets from the end, never the last one left.
    private static func resize(
        _ exercise: Exercise, by delta: Int, toward targets: [SetTarget], keeping kept: SetEntry?,
        in context: ModelContext
    ) {
        if delta > 0 {
            let next = (exercise.sortedSets.last?.order ?? -1) + 1
            for offset in 0..<delta {
                let index = min(exercise.sets.count, targets.count - 1)
                exercise.sets.append(SetEntry(target: targets[max(0, index)], order: next + offset))
            }
        } else if delta < 0 {
            let removable = exercise.sortedSets.reversed().filter { $0 !== kept }
            for set in removable.prefix(min(-delta, exercise.sets.count - 1)) { exercise.remove(set, in: context) }
        }
    }

    static func weeklyVolume(_ meso: Mesocycle, week: Int, planning: PlanningContext) -> [MuscleVolume] {
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
                    planned[muscle, default: 0] += exercise.sets.filter { $0.status != .skipped }.count
                    done[muscle, default: 0] += exercise.sets.filter(\.isDone).count
                }
            case .upcoming:
                for exercise in plan(meso, at: key, planning: planning) {
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

extension String {
    /// The text without surrounding whitespace, or `fallback` when nothing is left.
    fileprivate func trimmed(or fallback: String) -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

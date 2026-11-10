import Foundation
import SwiftData

@Model
public final class Workout {
    public var name: String = ""
    public internal(set) var startDate: Date = Date.now
    public internal(set) var endDate: Date?
    @Relationship(deleteRule: .cascade, originalName: "exercises", inverse: \Exercise.workout)
    var storedExercises: [Exercise]?
    public internal(set) var mesocycle: Mesocycle?
    public internal(set) var week: Int?
    public internal(set) var dayIndex: Int?
    /// Copied from the block day when the session is built, so a session-only relabel stays on this session.
    var weekdayRaw: String?
    @Relationship(deleteRule: .cascade, originalName: "feedback", inverse: \MuscleFeedbackRecord.workout)
    var storedFeedback: [MuscleFeedbackRecord]?
    public internal(set) var note: String?
    /// The lifter's body weight for this session, in their weight unit. Bodyweight lifts log load added to it.
    public internal(set) var bodyweight: Double?
    /// The RIR a logged block session was trained at, kept when the block's length changes after it. Nil reads the
    /// week's RIR from the block.
    var trainedRIR: Int?

    public internal(set) var exercises: [Exercise] {
        get { storedExercises ?? [] }
        set { storedExercises = newValue }
    }

    public var feedback: [MuscleFeedbackRecord] {
        get { storedFeedback ?? [] }
        set { storedFeedback = newValue }
    }

    public init(name: String, startDate: Date = .now) {
        self.name = name
        self.startDate = startDate
    }

    public internal(set) var weekday: Weekday? {
        get { weekdayRaw.flatMap(Weekday.init(rawValue:)) }
        set { weekdayRaw = newValue?.rawValue }
    }

    func setBodyweight(_ weight: Double?) {
        bodyweight = weight.flatMap { $0 > 0 ? $0 : nil }
    }

    /// The block day this session trains. A quick workout has none.
    var day: MesoDay? {
        guard let days = mesocycle?.sortedDays, let dayIndex, days.indices.contains(dayIndex) else { return nil }
        return days[dayIndex]
    }

    /// The note pinned to this session's day, which shows in place of the session's own note.
    public var pinnedNote: String? { day?.pinnedNote }

    /// A pinned note lives on the day, so every later session of it shows the note. Unpinning hands the
    /// text back to this session alone. A session with no day can't pin.
    func setNote(_ text: String, pinned: Bool) {
        if pinned, let day {
            day.pinnedNote = text.noteText
            note = nil
        } else {
            day?.pinnedNote = nil
            note = text.noteText
        }
    }

    public var sortedExercises: [Exercise] { exercises.sorted { $0.order < $1.order } }
    /// The order later weeks are planned in, which a session-only reorder keeps apart from `sortedExercises`.
    var plannedExercises: [Exercise] {
        exercises.sorted { ($0.plannedOrder ?? $0.order, $0.order) < ($1.plannedOrder ?? $1.order, $1.order) }
    }
    public var duration: TimeInterval { (endDate ?? .now).timeIntervalSince(startDate) }
    public var completedSets: Int { exercises.reduce(0) { $0 + $1.sets.filter(\.isDone).count } }
    /// The share of planned sets logged or skipped, from 0 to 1.
    public var setProgress: Double {
        let sets = exercises.flatMap(\.sets)
        return sets.isEmpty ? 0 : Double(sets.filter { $0.status != .pending }.count) / Double(sets.count)
    }
    public var isFullyLogged: Bool { !exercises.isEmpty && exercises.allSatisfy(\.isLogged) }
    /// Reps times moved load. A bodyweight lift without a body weight adds nothing, because its load is unknown.
    public var totalVolume: Double {
        exercises.reduce(0) { total, exercise in
            let loading = exercise.loading
            return exercise.sets.filter(\.isDone).reduce(total) {
                $0 + Double($1.reps) * (loading.movedLoad(of: $1.weight) ?? 0)
            }
        }
    }
    public var isFinished: Bool { endDate != nil }
    /// A session with a logged set, or a finished one, keeps its sets when its block changes around it.
    var hasLog: Bool { isFinished || completedSets > 0 }

    public var key: SessionKey? {
        guard let week, let dayIndex else { return nil }
        return SessionKey(week: week, dayIndex: dayIndex)
    }

    public var phase: WeekPhase? {
        guard let mesocycle, let week else { return nil }
        if let trainedRIR { return .accumulation(rir: trainedRIR) }
        return mesocycle.phase(week: week)
    }

    /// Reps in reserve the logged sets were aimed at. Free-form sessions count as all-out,
    /// which keeps 1RM estimates conservative. Deload sets say nothing about strength.
    var effortRIR: Int? {
        guard let phase else { return 0 }
        return phase.rir
    }

    var trainedMuscles: [Muscle] {
        var seen = Set<Muscle>()
        return sortedExercises.compactMap(\.muscle).filter { seen.insert($0).inserted }
    }

    func exercises(for muscle: Muscle) -> [Exercise] {
        sortedExercises.filter { $0.muscle == muscle }
    }

    func setCount(for muscle: Muscle) -> Int {
        exercises(for: muscle).reduce(0) { $0 + $1.sets.count }
    }

    /// Whether any set for `muscle` was actually done, as opposed to only prescribed.
    func trained(_ muscle: Muscle) -> Bool {
        exercises(for: muscle).contains { $0.sets.contains(where: \.isDone) }
    }

    /// Muscles whose last exercise has no pending set and that logged a set this session, in session order, so
    /// their feedback is due. A muscle whose sets were all skipped wasn't trained and has nothing to rate. Only block
    /// sessions collect feedback.
    public var feedbackMuscles: [Muscle] {
        guard mesocycle != nil else { return [] }
        let exercises = sortedExercises
        return trainedMuscles.filter { muscle in
            exercises.last { $0.muscle == muscle }?.isLogged == true && trained(muscle)
        }
    }

    /// The muscles in `feedbackMuscles` still owing their end-of-muscle answers, in session order. Until a muscle is
    /// rated, the sets of every other muscle wait for it.
    public var unratedFeedbackMuscles: [Muscle] {
        feedbackMuscles.filter { feedbackRecord(for: $0)?.value.isRated != true }
    }

    public func feedbackRecord(for muscle: Muscle) -> MuscleFeedbackRecord? {
        feedback.first { $0.muscleRaw == muscle.rawValue }
    }

    /// Earlier sessions in this block still waiting to hear how a muscle recovered, keyed by muscle.
    /// Soreness is only knowable once the muscle is trained again, so this session collects it.
    var pendingSoreness: [Muscle: MuscleFeedbackRecord] {
        guard let mesocycle, !isFinished else { return [:] }
        var pending: [Muscle: MuscleFeedbackRecord] = [:]
        for muscle in trainedMuscles {
            let previous = mesocycle.workouts
                .filter { $0 !== self && $0.isFinished && $0.startDate < startDate && $0.trained(muscle) }
                .max { $0.startDate < $1.startDate }
            if let record = previous?.feedbackRecord(for: muscle), record.value.soreness == nil {
                pending[muscle] = record
            }
        }
        return pending
    }

    func updateFeedback(for muscle: Muscle, _ change: (inout MuscleFeedback) -> Void) {
        let record =
            feedbackRecord(for: muscle)
            ?? {
                let record = MuscleFeedbackRecord(muscle: muscle)
                feedback.append(record)
                return record
            }()
        change(&record.value)
    }

    func remove(_ exercise: Exercise, in context: ModelContext) {
        exercises.removeAll { $0 === exercise }
        context.delete(exercise)
    }

    /// Clears everything logged and keeps the prescription: sets go back to their targets, and the
    /// feedback given for the day goes with the sets it described.
    func reset(in context: ModelContext) {
        for set in exercises.flatMap(\.sets) {
            set.status = .pending
            set.type = .regular
            set.weight = set.targetWeight ?? 0
            set.reps = set.targetReps ?? 0
        }
        for record in feedback { context.delete(record) }
        feedback.removeAll()
    }

    /// History keeps the pinned note this session showed, since the pin may change later.
    /// Free-form sessions drop what was never done. Mesocycle sessions keep the full prescription,
    /// because next week's plan is built from it and an untouched set means "repeat the target".
    func finish(in context: ModelContext) {
        if mesocycle == nil {
            for exercise in exercises {
                if !exercise.sets.contains(where: \.isDone) {
                    context.delete(exercise)
                } else {
                    for set in exercise.sets where !set.isDone { context.delete(set) }
                }
            }
        }
        note = note ?? pinnedNote
        endDate = .now
    }
}

extension Workout {
    public static var history: FetchDescriptor<Workout> {
        FetchDescriptor(
            predicate: #Predicate { $0.endDate != nil }, sortBy: [SortDescriptor(\.startDate, order: .reverse)])
    }

    public static var open: FetchDescriptor<Workout> {
        FetchDescriptor(
            predicate: #Predicate { $0.endDate == nil }, sortBy: [SortDescriptor(\.startDate, order: .reverse)])
    }
}
